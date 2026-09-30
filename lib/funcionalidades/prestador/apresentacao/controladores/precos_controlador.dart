import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/servico_modelo.dart';
import '../../dados/modelos/preco_modelo.dart';
import '../../dados/repositorios/precos_repositorio.dart';
import '../../dados/repositorios/prestador_repositorio.dart';

enum SituacaoGravacao { aGuardar, guardado, erro }

@immutable
class EstadoPrecos {
  const EstadoPrecos({
    required this.semRegisto,
    this.servicos = const [],
    this.precos = const {},
    this.proprios = const [],
    this.gravacoes = const {},
    this.errosGravacao = const {},
    this.errosCampo = const {},
    this.aAdicionar = false,
    this.errosNovo = const {},
    this.erroProprios,
  });

  /// O utilizador não tem linha em `prestadores`.
  final bool semRegisto;

  /// Serviços do catálogo da categoria do prestador.
  final List<ServicoModelo> servicos;

  /// Preços gravados, por `servico_id`. Só tem chave quando existe linha em
  /// `precos_prestador`; o valor nulo é "sob orçamento".
  final Map<String, int?> precos;
  final List<ServicoProprioModelo> proprios;

  /// Situação da última gravação de cada linha, pela [chaveCatalogo] ou
  /// [chaveProprio].
  final Map<String, SituacaoGravacao> gravacoes;
  final Map<String, String> errosGravacao;

  /// Valor escrito que não se pode gravar (ex.: zero).
  final Map<String, String> errosCampo;

  final bool aAdicionar;

  /// Erros do formulário de serviço próprio: `nome`, `valor`, `geral` (aqui
  /// entra a mensagem do limite de 3, vinda do gatilho).
  final Map<String, String> errosNovo;

  /// Erro ao remover um serviço próprio.
  final String? erroProprios;

  static String chaveCatalogo(String servicoId) => 'c:$servicoId';
  static String chaveProprio(String id) => 'p:$id';

  EstadoPrecos copiarCom({
    Map<String, int?>? precos,
    List<ServicoProprioModelo>? proprios,
    Map<String, SituacaoGravacao>? gravacoes,
    Map<String, String>? errosGravacao,
    Map<String, String>? errosCampo,
    bool? aAdicionar,
    Map<String, String>? errosNovo,
    String? erroProprios,
    bool limparErroProprios = false,
  }) => EstadoPrecos(
    semRegisto: semRegisto,
    servicos: servicos,
    precos: precos ?? this.precos,
    proprios: proprios ?? this.proprios,
    gravacoes: gravacoes ?? this.gravacoes,
    errosGravacao: errosGravacao ?? this.errosGravacao,
    errosCampo: errosCampo ?? this.errosCampo,
    aAdicionar: aAdicionar ?? this.aAdicionar,
    errosNovo: errosNovo ?? this.errosNovo,
    erroProprios: limparErroProprios
        ? null
        : (erroProprios ?? this.erroProprios),
  );
}

final precosControladorProvider =
    AsyncNotifierProvider.autoDispose<PrecosControlador, EstadoPrecos>(
      PrecosControlador.new,
    );

class PrecosControlador extends AutoDisposeAsyncNotifier<EstadoPrecos> {
  /// Espera depois da última tecla antes de gravar.
  static const esperaGravacao = Duration(milliseconds: 700);
  static const comprimentoMinimoNome = 3;

  late String _prestadorId;
  final _temporizadores = <String, Timer>{};
  final _pendentes = <String, Future<void> Function()>{};

  /// Última gravação de cada linha, para "tentar de novo".
  final _ultimas = <String, Future<void> Function()>{};

  PrecosRepositorio get _repositorio => ref.read(precosRepositorioProvider);

  @override
  Future<EstadoPrecos> build() async {
    ref.onDispose(_gravarPendentesAoSair);
    final prestadorId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (prestadorId == null) {
      throw const FalhaApp('Entre na sua conta para ver os seus preços.');
    }
    _prestadorId = prestadorId;

    final categoriaId = await ref
        .read(prestadorRepositorioProvider)
        .obterCategoriaId(prestadorId);
    if (categoriaId == null) return const EstadoPrecos(semRegisto: true);

    // Em paralelo; se algum falhar, `Future.wait` lança o primeiro erro, já
    // traduzido pelos repositórios.
    final resultados = await Future.wait<Object>([
      ref.watch(servicosProvider.future),
      _repositorio.listarPrecos(prestadorId),
      _repositorio.listarServicosProprios(prestadorId),
    ]);
    final servicos = resultados[0] as List<ServicoModelo>;
    final precos = resultados[1] as List<PrecoPrestadorModelo>;
    final proprios = resultados[2] as List<ServicoProprioModelo>;
    return EstadoPrecos(
      semRegisto: false,
      servicos: servicosDaCategoria(servicos, categoriaId),
      precos: {for (final preco in precos) preco.servicoId: preco.valor},
      proprios: proprios,
    );
  }

  // ── Edição ───────────────────────────────────────────────────────────────

  /// Chamado a cada tecla. Grava depois de [esperaGravacao] sem alterações.
  void alterarPrecoCatalogo(String servicoId, String texto) {
    final chave = EstadoPrecos.chaveCatalogo(servicoId);
    final valor = _validar(chave, texto);
    if (valor case (final int? v,)) {
      _actualizar((e) => e.copiarCom(precos: {...e.precos, servicoId: v}));
      _agendar(
        chave,
        () => _repositorio.guardarPreco(
          _prestadorId,
          PrecoPrestadorModelo(servicoId: servicoId, valor: v),
        ),
      );
    }
  }

  void alterarPrecoProprio(String id, String texto) {
    final chave = EstadoPrecos.chaveProprio(id);
    final valor = _validar(chave, texto);
    if (valor case (final int? v,)) {
      _actualizar(
        (e) => e.copiarCom(
          proprios: [
            for (final s in e.proprios)
              s.id == id
                  ? ServicoProprioModelo(id: s.id, nome: s.nome, valor: v)
                  : s,
          ],
        ),
      );
      _agendar(chave, () => _repositorio.alterarValorServicoProprio(id, v));
    }
  }

  /// Grava já o que estiver pendente nesta linha (o campo perdeu o foco).
  void confirmar(String chave) {
    if (_pendentes.containsKey(chave)) _executar(chave);
  }

  /// Repete a última gravação que falhou nesta linha.
  void repetir(String chave) {
    final ultima = _ultimas[chave];
    if (ultima == null) return;
    _pendentes[chave] = ultima;
    _executar(chave);
  }

  // ── Serviços próprios ────────────────────────────────────────────────────

  /// Devolve `true` se ficou gravado. O limite de 3 é do servidor: quando é
  /// atingido, o gatilho recusa e a mensagem dele aparece no formulário.
  Future<bool> adicionarServicoProprio({
    required String nome,
    required String valorTexto,
  }) async {
    final estado = state.valueOrNull;
    if (estado == null || estado.aAdicionar) return false;
    final nomeLimpo = nome.trim();
    final valor = _lerValor(valorTexto);
    final erros = <String, String>{
      if (nomeLimpo.length < comprimentoMinimoNome)
        'nome': 'Indique o nome do serviço.',
      if (valor == null) 'valor': _mensagemValorInvalido,
    };
    if (erros.isNotEmpty) {
      _actualizar((e) => e.copiarCom(errosNovo: erros));
      return false;
    }

    _actualizar((e) => e.copiarCom(aAdicionar: true, errosNovo: const {}));
    try {
      final criado = await _repositorio.adicionarServicoProprio(
        _prestadorId,
        ServicoProprioModelo(id: '', nome: nomeLimpo, valor: valor!.$1),
      );
      _actualizar(
        (e) =>
            e.copiarCom(aAdicionar: false, proprios: [...e.proprios, criado]),
      );
      return true;
    } on FalhaApp catch (falha) {
      // Inclui a recusa do gatilho `servicos_proprios` (máximo de 3), que
      // chega como `raise exception` com a mensagem já em português.
      _actualizar(
        (e) => e.copiarCom(
          aAdicionar: false,
          errosNovo: {'geral': falha.mensagem},
        ),
      );
      return false;
    }
  }

  Future<void> removerServicoProprio(String id) async {
    final chave = EstadoPrecos.chaveProprio(id);
    _temporizadores.remove(chave)?.cancel();
    _pendentes.remove(chave);
    try {
      await _repositorio.removerServicoProprio(id);
      _actualizar(
        (e) => e.copiarCom(
          proprios: [...e.proprios]..removeWhere((s) => s.id == id),
          errosNovo: const {},
          limparErroProprios: true,
        ),
      );
    } on FalhaApp catch (falha) {
      _actualizar((e) => e.copiarCom(erroProprios: falha.mensagem));
    }
  }

  // ── Regras ───────────────────────────────────────────────────────────────

  static const _mensagemValorInvalido =
      'Indique um valor maior que zero, ou deixe em branco para '
      '"sob orçamento".';

  /// `null` se o texto não é válido; senão, um registo com o valor (que pode
  /// ser nulo: campo em branco é "sob orçamento").
  (int?,)? _lerValor(String texto) {
    if (texto.trim().isEmpty) return (null,);
    final valor = lerMt(texto);
    return valor > 0 ? (valor,) : null;
  }

  (int?,)? _validar(String chave, String texto) {
    final valor = _lerValor(texto);
    _actualizar(
      (e) => e.copiarCom(
        errosCampo: valor == null
            ? {...e.errosCampo, chave: _mensagemValorInvalido}
            : ({...e.errosCampo}..remove(chave)),
      ),
    );
    if (valor == null) {
      // Não grava um valor inválido nem deixa gravar o anterior por cima.
      _temporizadores.remove(chave)?.cancel();
      _pendentes.remove(chave);
    }
    return valor;
  }

  // ── Gravação ─────────────────────────────────────────────────────────────

  void _agendar(String chave, Future<void> Function() gravar) {
    _pendentes[chave] = gravar;
    _temporizadores.remove(chave)?.cancel();
    _temporizadores[chave] = Timer(esperaGravacao, () => _executar(chave));
  }

  Future<void> _executar(String chave) async {
    _temporizadores.remove(chave)?.cancel();
    final gravar = _pendentes.remove(chave);
    if (gravar == null) return;
    _ultimas[chave] = gravar;
    _marcar(chave, SituacaoGravacao.aGuardar);
    try {
      await gravar();
      // Se entretanto o utilizador voltou a escrever, a próxima gravação é
      // que decide o que se mostra.
      if (!_pendentes.containsKey(chave)) {
        _marcar(chave, SituacaoGravacao.guardado);
      }
    } on FalhaApp catch (falha) {
      _marcar(chave, SituacaoGravacao.erro, erro: falha.mensagem);
    }
  }

  void _marcar(String chave, SituacaoGravacao situacao, {String? erro}) =>
      _actualizar(
        (e) => e.copiarCom(
          gravacoes: {...e.gravacoes, chave: situacao},
          errosGravacao: erro == null
              ? ({...e.errosGravacao}..remove(chave))
              : {...e.errosGravacao, chave: erro},
        ),
      );

  void _actualizar(EstadoPrecos Function(EstadoPrecos estado) alterar) {
    final estado = state.valueOrNull;
    if (estado != null) state = AsyncData(alterar(estado));
  }

  /// Ao sair do ecrã, grava o que ainda estava à espera, sem mexer no estado
  /// (o controlador já não existe para mostrar o resultado).
  void _gravarPendentesAoSair() {
    for (final temporizador in _temporizadores.values) {
      temporizador.cancel();
    }
    for (final gravar in _pendentes.values) {
      unawaited(gravar().catchError((_) {}));
    }
    _temporizadores.clear();
    _pendentes.clear();
  }
}
