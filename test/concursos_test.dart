import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/controladores/catalogo_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/categoria_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/servico_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/zona_modelo.dart';
import 'package:biscate_facil/funcionalidades/cliente/dados/repositorios/procura_repositorio.dart';
import 'package:biscate_facil/funcionalidades/concursos/apresentacao/controladores/concursos_controlador.dart';
import 'package:biscate_facil/funcionalidades/concursos/apresentacao/ecras/ecra_publicar_concurso.dart';
import 'package:biscate_facil/funcionalidades/concursos/dados/modelos/concurso_modelo.dart';
import 'package:biscate_facil/funcionalidades/concursos/dados/repositorios/concursos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/modelos/pedido_modelo.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/repositorios/pedidos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/ecras/ecra_gestao_pedidos.dart';
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

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'utilizador-1';
}

class _ProcuraFalsa extends ProcuraRepositorio {
  _ProcuraFalsa() : super(_clienteFalso);

  @override
  Future<String?> zonaDoCliente(String clienteId) async => 'fomento';
}

class _ConcursosFalsos extends ConcursosRepositorio {
  _ConcursosFalsos({this.faixa}) : super(_clienteFalso);

  final ReferenciaPrecoModelo? faixa;
  final publicados = <Map<String, dynamic>>[];
  final respostas = <Map<String, dynamic>>[];
  final adjudicadas = <String>[];
  bool jaRespondeu = false;

  @override
  Future<String> publicar(NovoConcursoModelo concurso) async {
    publicados.add(concurso.toJson());
    return 'concurso-1';
  }

  @override
  Future<ReferenciaPrecoModelo?> referencia({
    required String servicoId,
    required String municipio,
  }) async => faixa;

  @override
  Future<void> responder(NovaPropostaModelo proposta) async {
    if (jaRespondeu) throw const FalhaApp('Este registo já existe.');
    respostas.add(proposta.toJson());
  }

  @override
  Future<void> adjudicar(String propostaId) async =>
      adjudicadas.add(propostaId);

  @override
  Future<List<ConcursoModelo>> doCliente(String clienteId) async => const [];
}

const _concurso = ConcursoModelo(
  id: 'concurso-1',
  titulo: 'Substituir canos',
  estado: EstadoConcurso.aberto,
  orcamento: 1500,
);

List<Override> _substituicoes(_ConcursosFalsos concursos) => [
  autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
  procuraRepositorioProvider.overrideWithValue(_ProcuraFalsa()),
  concursosRepositorioProvider.overrideWithValue(concursos),
  sessaoProvider.overrideWith((ref) => Stream.value(null)),
  categoriasProvider.overrideWith(
    (ref) async => const [
      CategoriaModelo(id: 'canalizacao', nome: 'Canalização'),
    ],
  ),
  servicosProvider.overrideWith(
    (ref) async => const [
      ServicoModelo(
        id: 'desentupir',
        nome: 'Desentupimento',
        categoriaId: 'canalizacao',
      ),
    ],
  ),
  zonasProvider.overrideWith(
    (ref) async => const [
      ZonaModelo(id: 'fomento', nome: 'Fomento', municipio: 'Matola'),
    ],
  ),
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

  group('publicar', () {
    (ProviderContainer, _ConcursosFalsos) preparar() {
      final repo = _ConcursosFalsos();
      final container = ProviderContainer(overrides: _substituicoes(repo));
      addTearDown(container.dispose);
      final sub = container.listen(publicacaoControladorProvider, (_, _) {});
      addTearDown(sub.close);
      return (container, repo);
    }

    test('sem os campos obrigatórios não grava', () async {
      final (container, repo) = preparar();
      await container
          .read(publicacaoControladorProvider.notifier)
          .publicar(titulo: '', descricao: '', orcamento: '');
      expect(repo.publicados, isEmpty);
      expect(
        container.read(publicacaoControladorProvider).erros.keys,
        containsAll([
          'titulo',
          'categoria',
          'servico',
          'descricao',
          'orcamento',
        ]),
      );
    });

    test('grava com fecha_em a 48 h e a zona proposta do perfil', () async {
      final (container, repo) = preparar();
      final c = container.read(publicacaoControladorProvider.notifier);
      await Future<void>.delayed(Duration.zero); // zona do perfil
      c
        ..escolherCategoria('canalizacao')
        ..escolherServico('desentupir');
      final antes = DateTime.now().toUtc();
      await c.publicar(
        titulo: 'Substituir canos da casa de banho',
        descricao: 'Canos por baixo do lavatório com fuga.',
        orcamento: '1 500',
      );

      final json = repo.publicados.single;
      expect(json.containsKey('estado'), isFalse);
      expect(json['orcamento_cliente'], 1500);
      expect(json['zona_id'], 'fomento');
      expect(json['quando'], 'esta_semana');
      final fecha = DateTime.parse(json['fecha_em'] as String);
      final horas = fecha.difference(antes).inMinutes / 60;
      expect(horas, closeTo(48, 0.1));
      expect(container.read(publicacaoControladorProvider).publicado, isTrue);
    });
  });

  group('responder', () {
    (ProviderContainer, _ConcursosFalsos) preparar() {
      final repo = _ConcursosFalsos();
      final container = ProviderContainer(overrides: _substituicoes(repo));
      addTearDown(container.dispose);
      final sub = container.listen(
        respostaControladorProvider('concurso-1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      return (container, repo);
    }

    test(
      'contraproposta sem 15 caracteres de justificação não chega à base',
      () async {
        final (container, repo) = preparar();
        await container
            .read(respostaControladorProvider('concurso-1').notifier)
            .enviar(
              concurso: _concurso,
              valorTexto: '1 800',
              justificacao: 'Material caro',
            );
        expect(repo.respostas, isEmpty);
        expect(
          container
              .read(respostaControladorProvider('concurso-1'))
              .erros['justificacao'],
          contains('15'),
        );
      },
    );

    test('contraproposta válida envia tipo, valor e justificação', () async {
      final (container, repo) = preparar();
      await container
          .read(respostaControladorProvider('concurso-1').notifier)
          .enviar(
            concurso: _concurso,
            valorTexto: '1 800',
            justificacao: 'O orçamento não cobre o material.',
          );
      expect(repo.respostas.single, {
        'concurso_id': 'concurso-1',
        'prestador_id': 'utilizador-1',
        'tipo': 'contraproposta',
        'valor': 1800,
        'justificacao': 'O orçamento não cobre o material.',
      });
    });

    test(
      'aceitar o orçamento envia o valor do cliente, sem justificação',
      () async {
        final (container, repo) = preparar();
        final c = container.read(
          respostaControladorProvider('concurso-1').notifier,
        )..escolherTipo(TipoProposta.aceitaOrcamento);
        await c.enviar(concurso: _concurso, valorTexto: '', justificacao: '');
        expect(repo.respostas.single['tipo'], 'aceita_orcamento');
        expect(repo.respostas.single['valor'], 1500);
        expect(repo.respostas.single.containsKey('justificacao'), isFalse);
      },
    );

    test('responder duas vezes mostra "Já respondeu"', () async {
      final (container, repo) = preparar();
      repo.jaRespondeu = true;
      final c = container.read(
        respostaControladorProvider('concurso-1').notifier,
      )..escolherTipo(TipoProposta.aceitaOrcamento);
      await c.enviar(concurso: _concurso, valorTexto: '', justificacao: '');
      expect(
        container.read(respostaControladorProvider('concurso-1')).erroEnvio,
        'Já respondeu a este concurso.',
      );
    });
  });

  test('escolher uma proposta chama adjudicar_concurso', () async {
    final repo = _ConcursosFalsos();
    final container = ProviderContainer(overrides: _substituicoes(repo));
    addTearDown(container.dispose);
    final sub = container.listen(adjudicacaoControladorProvider, (_, _) {});
    addTearDown(sub.close);
    final erro = await container
        .read(adjudicacaoControladorProvider.notifier)
        .escolher('concurso-1', 'proposta-7');
    expect(erro, isNull);
    expect(repo.adjudicadas, ['proposta-7']);
  });

  group('faixa de referência ao publicar', () {
    Future<void> abrir(WidgetTester t, _ConcursosFalsos repo) async {
      t.view.physicalSize = const Size(360, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: _substituicoes(repo),
          child: MaterialApp(
            theme: construirTema(),
            home: const EcraPublicarConcurso(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Escolher').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Canalização').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Escolher').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Desentupimento').last);
      await t.pumpAndSettle();
    }

    testWidgets('com linha na vista, mostra a faixa do município', (t) async {
      await abrir(
        t,
        _ConcursosFalsos(
          faixa: const ReferenciaPrecoModelo(
            minimo: 1200,
            maximo: 2000,
            amostras: 8,
          ),
        ),
      );
      expect(
        find.text('Serviços parecidos em Matola: 1 200 – 2 000 MT'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('sem linha na vista, não mostra faixa nenhuma', (t) async {
      await abrir(t, _ConcursosFalsos());
      expect(find.textContaining('Serviços parecidos'), findsNothing);
    });
  });

  testWidgets('prestador vê o trabalho vindo de um concurso nos aceites', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final trabalho = TrabalhoModelo.fromJson({
      'id': 't1',
      'estado': 'agendado',
      'valor_acordado': 1800,
      'criado_em': '2026-09-30T08:00:00Z',
      'prestador_id': 'utilizador-1',
      'concurso_id': 'concurso-1',
      'concursos': {
        'titulo': 'Substituir canos',
        'descricao': 'Fuga por baixo do lavatório.',
        'endereco': 'Rua 4, casa 12',
        'zonas': {'nome': 'Fomento'},
      },
      'cliente': {'nome': 'Ana Sitoe', 'telefone': '841234567'},
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ..._substituicoes(_ConcursosFalsos()),
          pedidosRepositorioProvider.overrideWithValue(_PedidosVazios()),
          trabalhosRepositorioProvider.overrideWithValue(
            _TrabalhosDoPrestador([trabalho]),
          ),
        ],
        child: MaterialApp(
          theme: construirTema(),
          home: const EcraGestaoPedidos(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Aceites'));
    await t.pumpAndSettle();
    expect(find.text('Concurso'), findsOneWidget);
    expect(find.text('Substituir canos'), findsOneWidget);
    expect(find.text('Ana Sitoe'), findsOneWidget);
    expect(find.text('+258 841234567'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

class _PedidosVazios extends PedidosRepositorio {
  _PedidosVazios() : super(_clienteFalso);

  @override
  Future<List<PedidoModelo>> doPrestador(String prestadorId) async => const [];
}

class _TrabalhosDoPrestador extends TrabalhosRepositorio {
  _TrabalhosDoPrestador(this.lista) : super(_clienteFalso);

  final List<TrabalhoModelo> lista;

  @override
  Future<List<TrabalhoModelo>> deConcursosDoPrestador(
    String prestadorId,
  ) async => lista;
}
