import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../catalogo/dados/modelos/servico_modelo.dart';
import '../../../cliente/dados/modelos/prestador_publico_modelo.dart';
import '../../../cliente/dados/repositorios/procura_repositorio.dart';
import '../../dados/modelos/pedido_modelo.dart';
import '../../dados/repositorios/pedidos_repositorio.dart';
import 'pedidos_controlador.dart';

@immutable
class EstadoSolicitacao {
  const EstadoSolicitacao({
    this.servicoId,
    required this.data,
    this.periodo = PeriodoDia.manha,
    this.zonaId,
    this.fotos = const [],
    this.erros = const {},
    this.aEnviar = false,
    this.etapa,
    this.pedidoId,
    this.fotosEnviadas = const {},
    this.erroEnvio,
    this.enviado = false,
  });

  final String? servicoId;
  final DateTime data;
  final PeriodoDia periodo;
  final String? zonaId;
  final List<ImagemEscolhida> fotos;

  /// Erros por campo: `servico`, `descricao`, `zona`, `endereco`, `fotos`.
  final Map<String, String> erros;
  final bool aEnviar;

  /// O que está a acontecer durante o envio ("A enviar fotografia 1 de 2").
  final String? etapa;

  /// Preenchido quando o pedido já foi gravado. A partir daí o formulário
  /// fica fechado e repetir só envia as fotografias que faltam.
  final String? pedidoId;
  final Set<int> fotosEnviadas;
  final String? erroEnvio;
  final bool enviado;

  bool get pedidoGravado => pedidoId != null;

  EstadoSolicitacao copiarCom({
    String? servicoId,
    DateTime? data,
    PeriodoDia? periodo,
    String? zonaId,
    List<ImagemEscolhida>? fotos,
    Map<String, String>? erros,
    bool? aEnviar,
    String? etapa,
    bool limparEtapa = false,
    String? pedidoId,
    Set<int>? fotosEnviadas,
    String? erroEnvio,
    bool limparErroEnvio = false,
    bool? enviado,
  }) => EstadoSolicitacao(
    servicoId: servicoId ?? this.servicoId,
    data: data ?? this.data,
    periodo: periodo ?? this.periodo,
    zonaId: zonaId ?? this.zonaId,
    fotos: fotos ?? this.fotos,
    erros: erros ?? this.erros,
    aEnviar: aEnviar ?? this.aEnviar,
    etapa: limparEtapa ? null : (etapa ?? this.etapa),
    pedidoId: pedidoId ?? this.pedidoId,
    fotosEnviadas: fotosEnviadas ?? this.fotosEnviadas,
    erroEnvio: limparErroEnvio ? null : (erroEnvio ?? this.erroEnvio),
    enviado: enviado ?? this.enviado,
  );
}

/// Solicitação a um prestador (tela 07). A família é pelo `perfil_id` dele.
final solicitacaoControladorProvider = NotifierProvider.autoDispose
    .family<SolicitacaoControlador, EstadoSolicitacao, String>(
      SolicitacaoControlador.new,
    );

class SolicitacaoControlador
    extends AutoDisposeFamilyNotifier<EstadoSolicitacao, String> {
  static const maximoFotos = 4;
  static const comprimentoMinimoDescricao = 10;
  static const comprimentoMinimoEndereco = 5;
  static const diasDisponiveis = 7;

  final _comprimidas = <int, Uint8List>{};
  bool _descartado = false;

  String? get _clienteId =>
      ref.read(autenticacaoRepositorioProvider).utilizadorId;

  @override
  EstadoSolicitacao build(String prestadorId) {
    ref.onDispose(() => _descartado = true);
    _preencherZonaDoCliente();
    final hoje = DateTime.now();
    return EstadoSolicitacao(
      data: DateTime(hoje.year, hoje.month, hoje.day + 1),
    );
  }

  /// Propõe a zona do perfil do cliente; ele pode mudar.
  Future<void> _preencherZonaDoCliente() async {
    try {
      final clienteId = _clienteId;
      if (clienteId == null) return;
      final zonaId = await ref
          .read(procuraRepositorioProvider)
          .zonaDoCliente(clienteId);
      if (!_descartado && zonaId != null && state.zonaId == null) {
        state = state.copiarCom(zonaId: zonaId);
      }
    } catch (_) {
      // É só uma proposta: se falhar, seja porquê for, o cliente escolhe.
    }
  }

  // ── Campos ───────────────────────────────────────────────────────────────

  void escolherServico(String servicoId) =>
      _campo('servico', () => state.copiarCom(servicoId: servicoId));
  void escolherData(DateTime data) => state = state.copiarCom(data: data);
  void escolherPeriodo(PeriodoDia periodo) =>
      state = state.copiarCom(periodo: periodo);
  void escolherZona(String zonaId) =>
      _campo('zona', () => state.copiarCom(zonaId: zonaId));
  void limparErro(String campo) => _campo(campo, () => state);

  Future<void> adicionarFoto(OrigemImagem origem) async {
    if (state.pedidoGravado) return;
    if (state.fotos.length >= maximoFotos) {
      state = state.copiarCom(
        erros: {
          ...state.erros,
          'fotos': 'Pode juntar até $maximoFotos fotografias.',
        },
      );
      return;
    }
    final ImagemEscolhida? foto;
    try {
      foto = await ref.read(seletorImagemProvider).escolher(origem);
    } catch (_) {
      state = state.copiarCom(
        erros: {
          ...state.erros,
          'fotos':
              'Não foi possível abrir as fotografias. Autorize o acesso '
              'nas definições.',
        },
      );
      return;
    }
    if (foto == null || _descartado) return;
    state = state.copiarCom(fotos: [...state.fotos, foto]);
  }

  void removerFoto(int indice) {
    if (state.pedidoGravado) return;
    _comprimidas.clear();
    state = state.copiarCom(
      fotos: [...state.fotos]..removeAt(indice),
      erros: {...state.erros}..remove('fotos'),
    );
  }

  // ── Envio ────────────────────────────────────────────────────────────────

  /// Grava o pedido e envia as fotografias. Se o pedido já estiver gravado
  /// (uma tentativa anterior falhou nas fotografias), só envia as que faltam.
  Future<void> enviar({
    required String descricao,
    required String endereco,
  }) async {
    if (state.aEnviar || state.enviado) return;
    final clienteId = _clienteId;
    if (clienteId == null) {
      state = state.copiarCom(
        erroEnvio: 'Entre na sua conta para enviar o pedido.',
      );
      return;
    }
    // A base também o impede por restrição; aqui evita o pedido inútil.
    if (clienteId == arg) {
      state = state.copiarCom(
        erroEnvio: 'Não pode pedir um serviço a si próprio.',
      );
      return;
    }
    final descricaoLimpa = descricao.trim();
    final enderecoLimpo = endereco.trim();
    if (!state.pedidoGravado) {
      final erros = {
        if (state.servicoId == null) 'servico': 'Escolha o serviço.',
        if (descricaoLimpa.length < comprimentoMinimoDescricao)
          'descricao': 'Descreva o problema em poucas palavras.',
        if (state.zonaId == null) 'zona': 'Escolha o bairro.',
        if (enderecoLimpo.length < comprimentoMinimoEndereco)
          'endereco': 'Indique a rua e uma referência.',
      };
      if (erros.isNotEmpty) {
        state = state.copiarCom(erros: erros);
        return;
      }
    }

    state = state.copiarCom(aEnviar: true, limparErroEnvio: true);
    final repositorio = ref.read(pedidosRepositorioProvider);
    try {
      var pedidoId = state.pedidoId;
      if (pedidoId == null) {
        state = state.copiarCom(etapa: 'A enviar o pedido…');
        pedidoId = await repositorio.criar(
          NovoPedidoModelo(
            clienteId: clienteId,
            prestadorId: arg,
            servicoId: state.servicoId!,
            descricao: descricaoLimpa,
            dataPreferida: state.data,
            periodo: state.periodo,
            zonaId: state.zonaId!,
            endereco: enderecoLimpo,
          ),
        );
        if (_descartado) return;
        state = state.copiarCom(pedidoId: pedidoId);
      }

      final total = state.fotos.length;
      for (var i = 0; i < total; i++) {
        if (state.fotosEnviadas.contains(i)) continue;
        state = state.copiarCom(
          etapa: 'A enviar fotografia ${i + 1} de $total…',
        );
        final bytes = _comprimidas[i] ??= await _comprimir(state.fotos[i]);
        await repositorio.anexar(
          clienteId: clienteId,
          pedidoId: pedidoId,
          bytes: bytes,
        );
        if (_descartado) return;
        state = state.copiarCom(fotosEnviadas: {...state.fotosEnviadas, i});
      }

      state = state.copiarCom(aEnviar: false, limparEtapa: true, enviado: true);
      ref.invalidate(pedidosClienteProvider);
    } on FalhaApp catch (falha) {
      if (_descartado) return;
      state = state.copiarCom(
        aEnviar: false,
        limparEtapa: true,
        erroEnvio: state.pedidoGravado
            ? 'O pedido foi enviado, mas faltam fotografias. ${falha.mensagem}'
            : falha.mensagem,
      );
    }
  }

  /// Com o pedido já gravado, desiste das fotografias que faltam.
  void terminarSemFotografias() {
    if (!state.pedidoGravado || state.aEnviar) return;
    state = state.copiarCom(enviado: true, limparErroEnvio: true);
    ref.invalidate(pedidosClienteProvider);
  }

  Future<Uint8List> _comprimir(ImagemEscolhida foto) async {
    try {
      return await ref.read(compressorImagemProvider).comprimir(foto.bytes);
    } catch (_) {
      throw const FalhaApp('Não foi possível preparar uma das fotografias.');
    }
  }

  void _campo(String campo, EstadoSolicitacao Function() alterar) {
    final novo = alterar();
    state = novo.copiarCom(erros: {...novo.erros}..remove(campo));
  }
}

// ── Regras de apresentação ─────────────────────────────────────────────────

/// Os próximos dias que o cliente pode escolher, a começar em hoje.
List<DateTime> datasDisponiveis(DateTime hoje) => [
  for (var i = 0; i < SolicitacaoControlador.diasDisponiveis; i++)
    DateTime(hoje.year, hoje.month, hoje.day + i),
];

/// Serviços que se podem pedir a este prestador: os do catálogo a que ele
/// deu preço; se não deu preço a nenhum, todos os da categoria dele. Os
/// serviços próprios não entram (`pedidos.servico_id` aponta para
/// `servicos`).
List<(String id, String rotulo)> opcoesServico(
  PrestadorPublicoModelo prestador,
  List<ServicoModelo> catalogo,
) {
  final comPreco = [
    for (final p in prestador.precos)
      if (p.servicoId case final id?)
        (
          id,
          p.valor == null
              ? '${p.servico} · sob orçamento'
              : '${p.servico} · desde ${formatarMt(p.valor!)} MT',
        ),
  ];
  if (comPreco.isNotEmpty) return comPreco;
  return [
    for (final s in catalogo)
      if (s.categoriaId == prestador.categoriaId) (s.id, s.nome),
  ];
}
