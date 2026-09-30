import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/controladores/catalogo_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/servico_modelo.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/precos_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/modelos/preco_modelo.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/precos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/prestador_repositorio.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'prestador-1';
}

class _PrestadorFalso extends PrestadorRepositorio {
  _PrestadorFalso() : super(_clienteFalso);

  @override
  Future<String?> obterCategoriaId(String perfilId) async => 'electricidade';
}

class _PrecosFalso extends PrecosRepositorio {
  _PrecosFalso() : super(_clienteFalso);

  final gravados = <Map<String, dynamic>>[];
  final proprios = <ServicoProprioModelo>[
    const ServicoProprioModelo(id: 'p1', nome: 'Antena', valor: 300),
    const ServicoProprioModelo(id: 'p2', nome: 'Portão', valor: null),
    const ServicoProprioModelo(id: 'p3', nome: 'Alarme', valor: 900),
  ];
  var falharProximaGravacao = false;

  @override
  Future<List<PrecoPrestadorModelo>> listarPrecos(String prestadorId) async =>
      const [PrecoPrestadorModelo(servicoId: 'instalacao', valor: 500)];

  @override
  Future<void> guardarPreco(
    String prestadorId,
    PrecoPrestadorModelo preco,
  ) async {
    if (falharProximaGravacao) {
      falharProximaGravacao = false;
      throw const FalhaApp(mensagemSemLigacao);
    }
    gravados.add(preco.toJson(prestadorId));
  }

  @override
  Future<List<ServicoProprioModelo>> listarServicosProprios(
    String prestadorId,
  ) async => proprios;

  /// Como o gatilho real: com 3 já gravados, recusa com `raise exception`.
  @override
  Future<ServicoProprioModelo> adicionarServicoProprio(
    String prestadorId,
    ServicoProprioModelo servico,
  ) => executarTraduzido(() async {
    if (proprios.length >= 3) {
      throw const PostgrestException(
        message: 'Só pode ter até 3 serviços fora do catálogo.',
        code: 'P0001',
      );
    }
    final criado = ServicoProprioModelo(
      id: 'p${proprios.length + 1}',
      nome: servico.nome,
      valor: servico.valor,
    );
    proprios.add(criado);
    return criado;
  });

  @override
  Future<void> removerServicoProprio(String id) async =>
      proprios.removeWhere((s) => s.id == id);
}

Future<(ProviderContainer, _PrecosFalso)> _preparar() async {
  final precos = _PrecosFalso();
  final container = ProviderContainer(
    overrides: [
      autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
      prestadorRepositorioProvider.overrideWithValue(_PrestadorFalso()),
      precosRepositorioProvider.overrideWithValue(precos),
      servicosProvider.overrideWith(
        (ref) async => const [
          ServicoModelo(
            id: 'instalacao',
            nome: 'Instalação',
            categoriaId: 'electricidade',
          ),
          ServicoModelo(
            id: 'reparacao',
            nome: 'Reparação',
            categoriaId: 'electricidade',
          ),
          ServicoModelo(
            id: 'desentupir',
            nome: 'Desentupir',
            categoriaId: 'canalizacao',
          ),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(precosControladorProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(precosControladorProvider.future);
  return (container, precos);
}

EstadoPrecos _estado(ProviderContainer c) =>
    c.read(precosControladorProvider).requireValue;

Future<void> _esperarGravacao() =>
    Future<void>.delayed(PrecosControlador.esperaGravacao * 1.5);

void main() {
  test('carrega só os serviços da categoria, com o preço gravado', () async {
    final (container, _) = await _preparar();
    final estado = _estado(container);
    expect(estado.servicos.map((s) => s.id), ['instalacao', 'reparacao']);
    expect(estado.precos, {'instalacao': 500});
    expect(estado.proprios, hasLength(3));
  });

  test('grava uma vez depois de parar de escrever; em branco é nulo', () async {
    final (container, precos) = await _preparar();
    final c = container.read(precosControladorProvider.notifier);

    c.alterarPrecoCatalogo('reparacao', '3');
    c.alterarPrecoCatalogo('reparacao', '30');
    c.alterarPrecoCatalogo('reparacao', '300');
    expect(precos.gravados, isEmpty, reason: 'ainda à espera');
    await _esperarGravacao();
    expect(precos.gravados, [
      {'prestador_id': 'prestador-1', 'servico_id': 'reparacao', 'valor': 300},
    ]);

    c.alterarPrecoCatalogo('instalacao', '');
    c.confirmar(EstadoPrecos.chaveCatalogo('instalacao'));
    await Future<void>.delayed(Duration.zero);
    expect(precos.gravados.last['valor'], isNull, reason: 'sob orçamento');
    expect(
      _estado(container).gravacoes[EstadoPrecos.chaveCatalogo('instalacao')],
      SituacaoGravacao.guardado,
    );
  });

  test('valor zero não é gravado e mostra erro no campo', () async {
    final (container, precos) = await _preparar();
    final c = container.read(precosControladorProvider.notifier);
    c.alterarPrecoCatalogo('reparacao', '0');
    await _esperarGravacao();
    expect(precos.gravados, isEmpty);
    expect(
      _estado(container).errosCampo[EstadoPrecos.chaveCatalogo('reparacao')],
      isNotNull,
    );
  });

  test('falha na gravação fica marcada e tentar de novo grava', () async {
    final (container, precos) = await _preparar();
    final c = container.read(precosControladorProvider.notifier);
    final chave = EstadoPrecos.chaveCatalogo('reparacao');
    precos.falharProximaGravacao = true;

    c.alterarPrecoCatalogo('reparacao', '450');
    c.confirmar(chave);
    await Future<void>.delayed(Duration.zero);
    expect(_estado(container).gravacoes[chave], SituacaoGravacao.erro);
    expect(_estado(container).errosGravacao[chave], mensagemSemLigacao);

    c.repetir(chave);
    await Future<void>.delayed(Duration.zero);
    expect(_estado(container).gravacoes[chave], SituacaoGravacao.guardado);
    expect(precos.gravados.single['valor'], 450);
  });

  test('o quarto serviço próprio mostra a mensagem do gatilho', () async {
    final (container, precos) = await _preparar();
    final c = container.read(precosControladorProvider.notifier);

    final adicionado = await c.adicionarServicoProprio(
      nome: 'Frigoríficos',
      valorTexto: '700',
    );
    expect(adicionado, isFalse);
    expect(
      _estado(container).errosNovo['geral'],
      'Só pode ter até 3 serviços fora do catálogo.',
    );
    expect(precos.proprios, hasLength(3));

    await c.removerServicoProprio('p3');
    expect(
      await c.adicionarServicoProprio(nome: 'Frigoríficos', valorTexto: ''),
      isTrue,
    );
    expect(_estado(container).proprios.last.valor, isNull);
    expect(_estado(container).errosNovo, isEmpty);
  });
}
