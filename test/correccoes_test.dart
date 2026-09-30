import 'dart:io';

import 'package:biscate_facil/comum/widgets/componentes.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/editar_perfil_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/modelos/perfil_editavel_modelo.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/prestador_repositorio.dart';
import 'package:biscate_facil/funcionalidades/trabalhos/apresentacao/controladores/trabalhos_controlador.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient(
  'http://localhost',
  'chave-falsa',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'prestador-1';
}

class _PrestadorFalso extends PrestadorRepositorio {
  _PrestadorFalso() : super(_clienteFalso);

  final chamadas = <String>[];

  @override
  Future<void> guardarDadosProfissionais(
    String perfilId, {
    required String? titulo,
    required String? bio,
    required int? anosExperiencia,
  }) async => chamadas.add('prestadores: $titulo | $bio | $anosExperiencia');

  @override
  Future<void> guardarTelefone(String perfilId, String telefone) async =>
      chamadas.add('perfis.telefone: $telefone');

  @override
  Future<void> associarZonas({
    required String perfilId,
    required Set<String> zonaIds,
  }) async => chamadas.add('+zonas: ${zonaIds.toList()..sort()}');

  @override
  Future<void> removerZonas({
    required String perfilId,
    required Set<String> zonaIds,
  }) async => chamadas.add('-zonas: ${zonaIds.toList()..sort()}');
}

Future<void> _carregarFontes() async {
  Future<ByteData> ler(String f) async =>
      ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(ler('Manrope-$w.ttf'));
  }
  await manrope.load();
  await (FontLoader(
    'JetBrainsMono',
  )..addFont(ler('JetBrainsMono-400.ttf'))).load();
}

void main() {
  setUpAll(_carregarFontes);

  group('ganhos do mês', () {
    final agora = DateTime(2026, 9, 30, 12);

    test('soma este mês e o anterior, com variação', () {
      final g = resumirGanhos([
        (1500, DateTime(2026, 9, 3)),
        (500, DateTime(2026, 9, 29)),
        (1000, DateTime(2026, 8, 15)),
        (9999, DateTime(2026, 7, 31)), // fora da conta
      ], agora);
      expect(g.mesActual, 2000);
      expect(g.mesAnterior, 1000);
      expect(g.variacao, 100);
      expect(g.nomeMesAnterior, 'Agosto');
    });

    test('sem trabalhos: 0 MT e sem variação', () {
      final g = resumirGanhos(const [], agora);
      expect(g.mesActual, 0);
      expect(g.variacao, isNull);
    });

    test('sem ganhos no mês anterior, a variação esconde-se', () {
      final g = resumirGanhos([(800, DateTime(2026, 9, 2))], agora);
      expect(g.mesActual, 800);
      expect(g.variacao, isNull);
    });

    test('em Janeiro, o mês anterior é Dezembro', () {
      final g = resumirGanhos([
        (300, DateTime(2025, 12, 20)),
      ], DateTime(2026, 1, 10));
      expect(g.mesAnterior, 300);
      expect(g.nomeMesAnterior, 'Dezembro');
    });
  });

  group('editar perfil', () {
    const original = PerfilEditavelModelo(
      titulo: 'Electricista',
      bio: '',
      anosExperiencia: 8,
      zonaIds: {'fomento', 'machava'},
      telefone: '841234567',
    );

    (ProviderContainer, _PrestadorFalso) preparar() {
      final repo = _PrestadorFalso();
      final container = ProviderContainer(
        overrides: [
          autenticacaoRepositorioProvider.overrideWithValue(
            _AutenticacaoFalsa(),
          ),
          prestadorRepositorioProvider.overrideWithValue(repo),
          sessaoProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(edicaoPerfilControladorProvider, (_, _) {});
      addTearDown(sub.close);
      return (container, repo);
    }

    test(
      'grava os dados, o telefone só se mudou, e a diferença das zonas',
      () async {
        final (container, repo) = preparar();
        final c = container.read(edicaoPerfilControladorProvider.notifier)
          ..alternarZona('machava', original.zonaIds) // tira
          ..alternarZona('liberdade', original.zonaIds); // junta
        final gravado = await c.guardar(
          original: original,
          titulo: ' Electricista certificado ',
          bio: '',
          anos: '9',
          telefone: '+258 84 123 4567', // o mesmo número
        );
        expect(gravado, isTrue);
        expect(repo.chamadas, [
          'prestadores: Electricista certificado | null | 9',
          '+zonas: [liberdade]',
          '-zonas: [machava]',
        ]);
      },
    );

    test('telefone inválido e sem zonas não grava nada', () async {
      final (container, repo) = preparar();
      final c = container.read(edicaoPerfilControladorProvider.notifier)
        ..alternarZona('fomento', original.zonaIds)
        ..alternarZona('machava', original.zonaIds);
      final gravado = await c.guardar(
        original: original,
        titulo: 'Electricista',
        bio: '',
        anos: '8',
        telefone: '12345',
      );
      expect(gravado, isFalse);
      expect(repo.chamadas, isEmpty);
      expect(
        container.read(edicaoPerfilControladorProvider).erros.keys,
        containsAll(['telefone', 'zonas']),
      );
    });
  });

  group('folha de opções', () {
    Future<void> abrir(WidgetTester t, List<String> opcoes) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: construirTema(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      escolherOpcao(context, opcoes, '', titulo: 'Serviço'),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
    }

    testWidgets('com muitas opções rola, sem overflow, e tem procura', (
      t,
    ) async {
      await abrir(t, [for (var i = 1; i <= 30; i++) 'Serviço número $i']);
      expect(t.takeException(), isNull);
      expect(find.text('Procurar'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'número 2');
      await t.pumpAndSettle();
      // Ficam "número 2" e "número 20" a "número 29"; a lista só constrói as
      // linhas visíveis, por isso verifica-se o que entra e o que sai.
      expect(find.text('Serviço número 2'), findsOneWidget);
      expect(find.text('Serviço número 1'), findsNothing);
      expect(find.text('Serviço número 3'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('com poucas opções não mostra procura', (t) async {
      await abrir(t, const ['Manhã', 'Tarde']);
      expect(find.text('Procurar'), findsNothing);
      expect(find.text('Tarde'), findsOneWidget);
    });
  });
}
