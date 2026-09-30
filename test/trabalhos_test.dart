import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/cliente/apresentacao/ecras/ecra_meus_pedidos.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/modelos/pedido_modelo.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/repositorios/pedidos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/trabalhos/apresentacao/controladores/trabalhos_controlador.dart';
import 'package:biscate_facil/funcionalidades/trabalhos/dados/modelos/trabalho_modelo.dart';
import 'package:biscate_facil/funcionalidades/trabalhos/dados/repositorios/trabalhos_repositorio.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

Map<String, dynamic> _trabalho(
  String id, {
  String estado = 'agendado',
  bool avaliado = false,
  bool concurso = false,
}) => {
  'id': id,
  'estado': estado,
  'valor_acordado': 1500,
  'criado_em': '2026-09-2${id.length}T10:00:00Z',
  'prestador_id': 'prestador-$id',
  'concurso_id': concurso ? 'c1' : null,
  'servicos': concurso ? null : {'nome': 'Reparação eléctrica'},
  'concursos': concurso ? {'titulo': 'Substituir canos'} : null,
  'avaliacoes': avaliado
      ? [
          {'id': 'a1'},
        ]
      : <Object>[],
  'prestador': {
    'perfis': {'nome': 'Carlos Mabunda'},
  },
};

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'cliente-1';
}

class _TrabalhosFalsos extends TrabalhosRepositorio {
  _TrabalhosFalsos(this.lista) : super(_clienteFalso);

  final List<TrabalhoModelo> lista;
  final concluidos = <String>[];
  final avaliacoes = <Map<String, dynamic>>[];
  bool jaAvaliado = false;

  @override
  Future<List<TrabalhoModelo>> doCliente(String clienteId) async => lista;

  @override
  Future<void> concluir(String trabalhoId) async => concluidos.add(trabalhoId);

  @override
  Future<void> avaliar(NovaAvaliacaoModelo avaliacao) async {
    if (jaAvaliado) throw const FalhaApp('Este registo já existe.');
    avaliacoes.add(avaliacao.toJson());
  }
}

class _PedidosFalsos extends PedidosRepositorio {
  _PedidosFalsos(this.lista) : super(_clienteFalso);

  final List<PedidoModelo> lista;

  @override
  Future<List<PedidoModelo>> doCliente(String clienteId) async => lista;
}

List<Override> _substituicoes(
  _TrabalhosFalsos trabalhos, [
  List<PedidoModelo> pedidos = const [],
]) => [
  autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
  trabalhosRepositorioProvider.overrideWithValue(trabalhos),
  pedidosRepositorioProvider.overrideWithValue(_PedidosFalsos(pedidos)),
  sessaoProvider.overrideWith((ref) => Stream.value(null)),
];

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

  test('modelo: avaliado, origem em concurso e nome do serviço', () {
    final deConcurso = TrabalhoModelo.fromJson(
      _trabalho('t1', estado: 'concluido', avaliado: true, concurso: true),
    );
    expect(deConcurso.origemConcurso, isTrue);
    expect(deConcurso.servico, 'Substituir canos');
    expect(deConcurso.avaliado, isTrue);
    expect(deConcurso.concluido, isTrue);

    final emCurso = TrabalhoModelo.fromJson(_trabalho('t2'));
    expect(emCurso.emCurso, isTrue);
    expect(emCurso.servico, 'Reparação eléctrica');
    expect(emCurso.prestadorNome, 'Carlos Mabunda');
  });

  test('concluir chama o update do trabalho', () async {
    final repo = _TrabalhosFalsos(const []);
    final container = ProviderContainer(overrides: _substituicoes(repo));
    addTearDown(container.dispose);
    final sub = container.listen(conclusaoControladorProvider, (_, _) {});
    addTearDown(sub.close);

    final erro = await container
        .read(conclusaoControladorProvider.notifier)
        .concluir('t2');
    expect(erro, isNull);
    expect(repo.concluidos, ['t2']);
  });

  group('avaliação', () {
    (ProviderContainer, _TrabalhosFalsos) preparar() {
      final repo = _TrabalhosFalsos(const []);
      final container = ProviderContainer(overrides: _substituicoes(repo));
      addTearDown(container.dispose);
      final sub = container.listen(
        avaliacaoControladorProvider('t1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      return (container, repo);
    }

    test('sem estrelas nem recomendação não envia', () async {
      final (container, repo) = preparar();
      await container
          .read(avaliacaoControladorProvider('t1').notifier)
          .enviar(prestadorId: 'p', comentario: '');
      expect(repo.avaliacoes, isEmpty);
      expect(
        container.read(avaliacaoControladorProvider('t1')).erros.keys,
        containsAll(['estrelas', 'recomenda']),
      );
    });

    test('envia só trabalho_id, estrelas, comentario e recomenda', () async {
      final (container, repo) = preparar();
      final c = container.read(avaliacaoControladorProvider('t1').notifier);
      c
        ..escolherEstrelas(4)
        ..escolherRecomenda(true);
      await c.enviar(prestadorId: 'p', comentario: '  Chegou a horas.  ');
      expect(repo.avaliacoes.single, {
        'trabalho_id': 't1',
        'estrelas': 4,
        'comentario': 'Chegou a horas.',
        'recomenda': true,
      });
      expect(
        container.read(avaliacaoControladorProvider('t1')).enviada,
        isTrue,
      );
    });

    test('avaliar duas vezes mostra "Já avaliou"', () async {
      final (container, repo) = preparar();
      repo.jaAvaliado = true;
      final c = container.read(avaliacaoControladorProvider('t1').notifier);
      c
        ..escolherEstrelas(5)
        ..escolherRecomenda(false);
      await c.enviar(prestadorId: 'p', comentario: '');
      expect(
        container.read(avaliacaoControladorProvider('t1')).erroEnvio,
        'Já avaliou este trabalho.',
      );
    });
  });

  testWidgets('meus pedidos junta pedidos e trabalhos sem duplicar', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final pedidos = [
      PedidoModelo.fromJson({
        'id': 'p1',
        'estado': 'pendente',
        'criado_em': '2026-09-29T10:00:00Z',
        'servicos': {'nome': 'Pintura'},
      }),
      // Aceite: aparece como trabalho, não como pedido.
      PedidoModelo.fromJson({
        'id': 'p2',
        'estado': 'aceite',
        'servicos': {'nome': 'Reparação eléctrica'},
      }),
    ];
    final trabalhos = [
      TrabalhoModelo.fromJson(_trabalho('t2')),
      TrabalhoModelo.fromJson(_trabalho('t33', estado: 'concluido')),
      TrabalhoModelo.fromJson(
        _trabalho('t444', estado: 'concluido', avaliado: true, concurso: true),
      ),
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: _substituicoes(_TrabalhosFalsos(trabalhos), pedidos),
        child: MaterialApp(
          theme: construirTema(),
          home: const EcraMeusPedidos(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Activos (2)'), findsOneWidget);
    expect(find.text('Pintura'), findsOneWidget);
    expect(find.text('Reparação eléctrica'), findsOneWidget);
    expect(find.text('Marcar como concluído'), findsOneWidget);

    await t.tap(find.text('Histórico'));
    await t.pumpAndSettle();
    expect(find.text('Avaliar o serviço ›'), findsOneWidget);
    expect(find.text('Avaliado ✓'), findsOneWidget);
    expect(find.text('Concurso'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
