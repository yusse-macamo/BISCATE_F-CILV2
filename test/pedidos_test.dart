import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/cliente/dados/repositorios/procura_repositorio.dart';
import 'package:biscate_facil/funcionalidades/pedidos/apresentacao/controladores/pedidos_controlador.dart';
import 'package:biscate_facil/funcionalidades/pedidos/apresentacao/controladores/solicitacao_controlador.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/modelos/pedido_modelo.dart';
import 'package:biscate_facil/funcionalidades/pedidos/dados/repositorios/pedidos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/ecras/ecra_gestao_pedidos.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:biscate_facil/nucleo/utilitarios/imagens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

/// Um pedido pendente como a base o devolve ao prestador: sem trabalho, e com
/// o perfil do cliente escondido pela RLS (`cliente: null`).
const _pendente = {
  'id': 'p1',
  'estado': 'pendente',
  'descricao': 'Tomadas da cozinha sem corrente.',
  'data_preferida': '2026-10-04',
  'periodo': 'manha',
  'endereco': 'Rua 4, casa 12',
  'criado_em': '2026-09-30T08:00:00Z',
  'servicos': {'nome': 'Reparação eléctrica'},
  'zonas': {'nome': 'Fomento'},
  'anexos': [
    {'id': 'a1'},
    {'id': 'a2'},
  ],
  'trabalhos': <Object>[],
  'prestador': {
    'perfis': {'nome': 'Carlos Mabunda'},
  },
  'cliente': null,
};

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

class _PedidosFalsos extends PedidosRepositorio {
  _PedidosFalsos() : super(_clienteFalso);

  final criados = <Map<String, dynamic>>[];
  final anexados = <String>[];
  final aceites = <(String, int?)>[];
  final rejeitados = <String>[];

  /// Número da chamada a [anexar] (a contar de 0) que falha.
  int? falharAnexoUmaVez;
  var _tentativasAnexo = 0;

  @override
  Future<String> criar(NovoPedidoModelo pedido) async {
    criados.add(pedido.toJson());
    return 'pedido-${criados.length}';
  }

  @override
  Future<void> anexar({
    required String clienteId,
    required String pedidoId,
    required Uint8List bytes,
  }) async {
    if (falharAnexoUmaVez == _tentativasAnexo++) {
      falharAnexoUmaVez = null;
      throw const FalhaApp(mensagemSemLigacao);
    }
    anexados.add('$clienteId/$pedidoId');
  }

  @override
  Future<List<PedidoModelo>> doPrestador(String prestadorId) async => [
    PedidoModelo.fromJson(_pendente),
  ];

  @override
  Future<void> aceitar(String pedidoId, {int? valorAcordado}) async =>
      aceites.add((pedidoId, valorAcordado));

  @override
  Future<void> rejeitar(String pedidoId) async => rejeitados.add(pedidoId);
}

class _SeletorFalso extends SeletorImagem {
  @override
  Future<ImagemEscolhida?> escolher(OrigemImagem origem) async =>
      ImagemEscolhida(nome: 'foto.jpg', bytes: Uint8List.fromList([1, 2, 3]));
}

class _CompressorFalso extends CompressorImagem {
  int chamadas = 0;

  @override
  Future<Uint8List> comprimir(Uint8List original) async {
    chamadas++;
    return original;
  }
}

List<Override> _substituicoes(
  _PedidosFalsos pedidos, [
  _CompressorFalso? compressor,
]) => [
  autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
  procuraRepositorioProvider.overrideWithValue(_ProcuraFalsa()),
  pedidosRepositorioProvider.overrideWithValue(pedidos),
  seletorImagemProvider.overrideWithValue(_SeletorFalso()),
  compressorImagemProvider.overrideWithValue(compressor ?? _CompressorFalso()),
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

  group('modelo', () {
    test('cliente escondido pela RLS chega como nulo, não como erro', () {
      final pedido = PedidoModelo.fromJson(_pendente);
      expect(pedido.cliente, isNull);
      expect(pedido.trabalho, isNull);
      expect(pedido.numeroAnexos, 2);
      expect(pedido.prestadorNome, 'Carlos Mabunda');
      expect(situacaoDe(pedido), SituacaoPedido.pendente);
    });

    test('anexos: URL por caminho; linhas estragadas não rebentam', () {
      final pedido = PedidoModelo.fromJson({
        ..._pendente,
        'anexos': [
          {'id': 'a1', 'caminho': 'cliente-1/pedido_1.jpg'},
          {'id': 'a2', 'caminho': null},
          'lixo',
        ],
      }, urlAnexo: (caminho) => 'https://x/$caminho');
      expect(pedido.fotosAnexos, ['https://x/cliente-1/pedido_1.jpg']);

      final semEmbed = PedidoModelo.fromJson({..._pendente, 'anexos': null});
      expect(semEmbed.fotosAnexos, isEmpty);
      expect(semEmbed.numeroAnexos, 0);
    });

    test('aceite com trabalho: em curso, e depois concluído', () {
      final aceite = PedidoModelo.fromJson({
        ..._pendente,
        'estado': 'aceite',
        'trabalhos': [
          {'estado': 'agendado', 'valor_acordado': 1500},
        ],
        'cliente': {'nome': 'Ana Sitoe', 'telefone': '841234567'},
      });
      expect(situacaoDe(aceite), SituacaoPedido.emCurso);
      expect(aceite.trabalho!.valorAcordado, 1500);
      expect(aceite.cliente!.telefone, '841234567');

      final concluido = PedidoModelo.fromJson({
        ..._pendente,
        'estado': 'aceite',
        'trabalhos': [
          {'estado': 'concluido', 'valor_acordado': null},
        ],
      });
      expect(situacaoDe(concluido), SituacaoPedido.concluido);
    });

    test('o que se envia: sem estado, data como date, período da base', () {
      final json = NovoPedidoModelo(
        clienteId: 'c',
        prestadorId: 'p',
        servicoId: 's',
        descricao: 'd',
        dataPreferida: DateTime(2026, 10, 4, 15, 30),
        periodo: PeriodoDia.qualquer,
        zonaId: 'fomento',
        endereco: 'Rua 4',
      ).toJson();
      expect(json.containsKey('estado'), isFalse);
      expect(json['data_preferida'], '2026-10-04');
      expect(json['periodo'], 'qualquer');
      expect(PeriodoDia.values.map((p) => p.name), [
        'manha',
        'tarde',
        'qualquer',
      ]);
    });

    test('datas e tempo decorrido', () {
      final hoje = DateTime(2026, 9, 30);
      expect(rotuloData(hoje, hoje), 'Hoje');
      expect(rotuloData(DateTime(2026, 10, 1), hoje), 'Amanhã');
      expect(rotuloData(DateTime(2026, 10, 3), hoje), 'Sáb, 3 Out');
      final agora = DateTime(2026, 9, 30, 12);
      expect(haQuanto(DateTime(2026, 9, 30, 11, 48), agora), 'Há 12 min');
      expect(haQuanto(DateTime(2026, 9, 28, 12), agora), 'Há 2 dias');
    });
  });

  test('solicitação: sem campos obrigatórios não grava', () async {
    final pedidos = _PedidosFalsos();
    final container = ProviderContainer(overrides: _substituicoes(pedidos));
    addTearDown(container.dispose);
    final provider = solicitacaoControladorProvider('prestador-1');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await container
        .read(provider.notifier)
        .enviar(descricao: 'curta', endereco: '');
    expect(pedidos.criados, isEmpty);
    expect(
      container.read(provider).erros.keys,
      containsAll(['servico', 'descricao', 'endereco']),
    );
  });

  test(
    'repetir depois de falhar uma fotografia não cria outro pedido',
    () async {
      final pedidos = _PedidosFalsos()..falharAnexoUmaVez = 1;
      final compressor = _CompressorFalso();
      final container = ProviderContainer(
        overrides: _substituicoes(pedidos, compressor),
      );
      addTearDown(container.dispose);
      final provider = solicitacaoControladorProvider('prestador-1');
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final c = container.read(provider.notifier);
      await Future<void>.delayed(Duration.zero); // zona proposta do perfil

      c.escolherServico('reparacao');
      await c.adicionarFoto(OrigemImagem.galeria);
      await c.adicionarFoto(OrigemImagem.camara);
      await c.enviar(
        descricao: 'Tomadas da cozinha sem corrente.',
        endereco: 'Rua 4, casa 12',
      );

      var estado = container.read(provider);
      expect(estado.pedidoGravado, isTrue);
      expect(estado.enviado, isFalse);
      expect(estado.erroEnvio, contains('faltam fotografias'));
      expect(pedidos.criados, hasLength(1));
      expect(pedidos.criados.single['zona_id'], 'fomento');
      expect(pedidos.anexados, ['utilizador-1/pedido-1']);

      await c.enviar(descricao: '', endereco: '');
      estado = container.read(provider);
      expect(estado.enviado, isTrue);
      expect(pedidos.criados, hasLength(1), reason: 'não repete o pedido');
      expect(pedidos.anexados, [
        'utilizador-1/pedido-1',
        'utilizador-1/pedido-1',
      ]);
      expect(compressor.chamadas, 2, reason: 'não volta a comprimir');
    },
  );

  test('aceitar chama a função do servidor; rejeitar muda o estado', () async {
    final pedidos = _PedidosFalsos();
    final container = ProviderContainer(overrides: _substituicoes(pedidos));
    addTearDown(container.dispose);
    final sub = container.listen(respostaPedidoControladorProvider, (_, _) {});
    addTearDown(sub.close);
    final c = container.read(respostaPedidoControladorProvider.notifier);

    expect(await c.aceitar('p1', valorAcordado: 1500), isNull);
    expect(await c.rejeitar('p2'), isNull);
    expect(pedidos.aceites, [('p1', 1500)]);
    expect(pedidos.rejeitados, ['p2']);
  });

  testWidgets(
    'gestão: sem contacto antes de aceitar é normal e cabe a 360×760',
    (testador) async {
      testador.view.physicalSize = const Size(360, 760);
      testador.view.devicePixelRatio = 1;
      addTearDown(testador.view.reset);
      await testador.pumpWidget(
        ProviderScope(
          overrides: _substituicoes(_PedidosFalsos()),
          child: MaterialApp(
            theme: construirTema(),
            home: const EcraGestaoPedidos(),
          ),
        ),
      );
      await testador.pumpAndSettle();
      expect(find.text('Novos (1)'), findsOneWidget);
      expect(find.text('Reparação eléctrica'), findsOneWidget);
      expect(find.text('2 fotografias'), findsOneWidget);
      expect(
        find.text(
          'Nome e contacto do cliente ficam visíveis depois de aceitar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsNothing, reason: 'não é erro');
      expect(testador.takeException(), isNull);
    },
  );
}
