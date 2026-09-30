import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/assinatura_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/ecras/ecra_assinatura.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/assinatura_repositorio.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sem renovação automática do token: é um temporizador periódico que ficaria
// pendente no fim dos testes de widgets.
final _clienteFalso = SupabaseClient(
  'http://localhost',
  'chave-falsa',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

const _planos = [
  PlanoModelo(id: 'basico', nome: 'Básico', preco: 100),
  PlanoModelo(id: 'premium', nome: 'Premium', preco: 200),
];

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'prestador-1';
}

/// Só leitura: não tem nenhum método de escrita para o botão chamar.
class _AssinaturaFalsa extends AssinaturaRepositorio {
  _AssinaturaFalsa({this.assinatura, this.falharPagamentos = false})
    : super(_clienteFalso);

  final AssinaturaModelo? assinatura;
  final bool falharPagamentos;

  @override
  Future<List<PlanoModelo>> planos() async => _planos;

  @override
  Future<AssinaturaModelo?> actual(String prestadorId) async => assinatura;

  @override
  Future<EstadoGratuitoModelo?> estadoGratuito(String prestadorId) async =>
      null;

  @override
  Future<List<PagamentoModelo>> pagamentos(
    String prestadorId, {
    int limite = 12,
  }) async {
    if (falharPagamentos) throw const FalhaApp(mensagemSemLigacao);
    return [
      PagamentoModelo(
        valor: 200,
        referencia: 'MP-001',
        data: DateTime(2026, 9, 1),
        planoNome: 'Premium',
      ),
    ];
  }
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

  test('selo e resumo vêm da assinatura ou do período gratuito', () {
    final activa = SituacaoAssinatura(
      planos: _planos,
      assinatura: AssinaturaModelo(
        planoId: 'premium',
        planoNome: 'Premium',
        activa: true,
        fim: DateTime(2026, 10, 30),
      ),
    );
    expect(textoSeloPlano(activa), 'Premium');
    expect(resumoSituacao(activa), 'Plano Premium activo até 30/10/2026.');

    const gratuito = SituacaoAssinatura(
      planos: _planos,
      gratuito: EstadoGratuitoModelo(diasRestantes: 12, trabalhosRestantes: 2),
    );
    expect(textoSeloPlano(gratuito), 'Grátis');
    expect(resumoSituacao(gratuito), contains('faltam 12 dias ou 2 trabalhos'));

    const nada = SituacaoAssinatura(planos: _planos);
    expect(textoSeloPlano(nada), isNull);
  });

  Future<void> abrir(WidgetTester t, _AssinaturaFalsa repo) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          autenticacaoRepositorioProvider.overrideWithValue(
            _AutenticacaoFalsa(),
          ),
          assinaturaRepositorioProvider.overrideWithValue(repo),
          sessaoProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: construirTema(),
          home: const EcraAssinatura(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('mostra planos, plano actual e pagamentos; o botão simula', (
    t,
  ) async {
    await abrir(
      t,
      _AssinaturaFalsa(
        assinatura: const AssinaturaModelo(
          planoId: 'premium',
          planoNome: 'Premium',
          activa: true,
        ),
      ),
    );
    expect(find.text('Básico'), findsOneWidget);
    expect(find.text('O seu plano actual'), findsOneWidget);
    expect(find.text('1/9/2026 · Premium'), findsOneWidget);

    await t.tap(find.text('Escolher Premium'));
    await t.pump();
    expect(find.textContaining('ainda não está disponível'), findsOneWidget);
    expect(t.takeException(), isNull);
    // Deixa o aviso sair, para não sobrar o temporizador dele.
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
  });

  testWidgets('falha nos pagamentos não esconde os planos', (t) async {
    await abrir(t, _AssinaturaFalsa(falharPagamentos: true));
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text(mensagemSemLigacao), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
