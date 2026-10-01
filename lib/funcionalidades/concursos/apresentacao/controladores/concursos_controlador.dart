import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../cliente/dados/repositorios/procura_repositorio.dart';
import '../../../prestador/dados/repositorios/prestador_repositorio.dart';
import '../../dados/modelos/concurso_modelo.dart';
import '../../dados/repositorios/concursos_repositorio.dart';

Future<String> _utilizador(Ref ref, String mensagem) async {
  await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
  final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
  if (id == null) throw FalhaApp(mensagem);
  return id;
}

// ── Leituras ────────────────────────────────────────────────────────────────

/// Concursos publicados pelo cliente autenticado.
final meusConcursosProvider = FutureProvider.autoDispose<List<ConcursoModelo>>((
  ref,
) async {
  final id = await _utilizador(ref, 'Entre na sua conta.');
  return ref.watch(concursosRepositorioProvider).doCliente(id);
});

/// Um concurso. O `prestadorId` (se houver sessão) serve para saber se o
/// prestador já respondeu.
final concursoProvider = FutureProvider.autoDispose
    .family<ConcursoModelo?, String>((ref, concursoId) async {
      if (concursoId.isEmpty) return null;
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      return ref
          .watch(concursosRepositorioProvider)
          .obter(concursoId, prestadorId: id);
    });

/// Telefone do prestador escolhido num concurso, `null` enquanto o contacto
/// não estiver libertado. Uma falha também dá `null`: os botões de contacto
/// ficam escondidos e o resto do ecrã continua.
final telefoneEscolhidoProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, concursoId) async {
      try {
        return await ref
            .watch(concursosRepositorioProvider)
            .telefoneDoEscolhido(concursoId);
      } on FalhaApp {
        return null;
      }
    });

final propostasProvider = FutureProvider.autoDispose
    .family<List<PropostaModelo>, String>((ref, concursoId) async {
      if (concursoId.isEmpty) return const [];
      return ref.watch(concursosRepositorioProvider).propostas(concursoId);
    });

/// Concursos abertos da categoria e das zonas do prestador (tela 17). Sem
/// mapa, a proximidade é a zona; não há filtro de distância.
final oportunidadesProvider = FutureProvider.autoDispose<List<ConcursoModelo>>((
  ref,
) async {
  final id = await _utilizador(
    ref,
    'Entre na sua conta de prestador para ver oportunidades.',
  );
  final categoriaId = await ref
      .watch(prestadorRepositorioProvider)
      .obterCategoriaId(id);
  if (categoriaId == null) return const [];
  final repositorio = ref.watch(concursosRepositorioProvider);
  final zonas = await repositorio.zonasDoPrestador(id);
  return repositorio.oportunidades(
    prestadorId: id,
    categoriaId: categoriaId,
    zonaIds: zonas,
  );
});

/// Faixa de referência de preços. `null` quando a vista não tem linha, ou
/// quando falta o serviço ou o município: não se inventa intervalo.
final referenciaPrecoProvider = FutureProvider.autoDispose
    .family<ReferenciaPrecoModelo?, (String?, String?)>((ref, chave) async {
      final (servicoId, municipio) = chave;
      if (servicoId == null || municipio == null) return null;
      return ref
          .watch(concursosRepositorioProvider)
          .referencia(servicoId: servicoId, municipio: municipio);
    });

// ── Publicar (tela 16) ─────────────────────────────────────────────────────

@immutable
class EstadoPublicacao {
  const EstadoPublicacao({
    this.categoriaId,
    this.servicoId,
    this.outroServico = false,
    this.quando = Urgencia.estaSemana,
    this.zonaId,
    this.fotos = const [],
    this.erros = const {},
    this.aEnviar = false,
    this.etapa,
    this.concursoId,
    this.fotosEnviadas = const {},
    this.erroEnvio,
    this.publicado = false,
  });

  final String? categoriaId;
  final String? servicoId;

  /// O cliente escolheu "Outro serviço": não há `servico_id` e o que precisa
  /// vai escrito no texto do concurso.
  final bool outroServico;
  final Urgencia quando;
  final String? zonaId;
  final List<ImagemEscolhida> fotos;

  /// `titulo`, `categoria`, `servico`, `outro`, `descricao`, `orcamento`,
  /// `zona`.
  final Map<String, String> erros;
  final bool aEnviar;
  final String? etapa;

  /// Preenchido quando o concurso já foi gravado; repetir só envia as
  /// fotografias que faltam.
  final String? concursoId;
  final Set<int> fotosEnviadas;
  final String? erroEnvio;
  final bool publicado;

  bool get gravado => concursoId != null;

  EstadoPublicacao copiarCom({
    String? categoriaId,
    String? servicoId,
    bool limparServico = false,
    bool? outroServico,
    Urgencia? quando,
    String? zonaId,
    List<ImagemEscolhida>? fotos,
    Map<String, String>? erros,
    bool? aEnviar,
    String? etapa,
    bool limparEtapa = false,
    String? concursoId,
    Set<int>? fotosEnviadas,
    String? erroEnvio,
    bool limparErroEnvio = false,
    bool? publicado,
  }) => EstadoPublicacao(
    categoriaId: categoriaId ?? this.categoriaId,
    servicoId: limparServico ? null : (servicoId ?? this.servicoId),
    outroServico: outroServico ?? this.outroServico,
    quando: quando ?? this.quando,
    zonaId: zonaId ?? this.zonaId,
    fotos: fotos ?? this.fotos,
    erros: erros ?? this.erros,
    aEnviar: aEnviar ?? this.aEnviar,
    etapa: limparEtapa ? null : (etapa ?? this.etapa),
    concursoId: concursoId ?? this.concursoId,
    fotosEnviadas: fotosEnviadas ?? this.fotosEnviadas,
    erroEnvio: limparErroEnvio ? null : (erroEnvio ?? this.erroEnvio),
    publicado: publicado ?? this.publicado,
  );
}

final publicacaoControladorProvider =
    NotifierProvider.autoDispose<PublicacaoControlador, EstadoPublicacao>(
      PublicacaoControlador.new,
    );

class PublicacaoControlador extends AutoDisposeNotifier<EstadoPublicacao> {
  static const maximoFotos = 4;
  static const tituloMinimo = 5;
  static const descricaoMinima = 10;

  final _comprimidas = <int, Uint8List>{};
  bool _descartado = false;

  String? get _clienteId =>
      ref.read(autenticacaoRepositorioProvider).utilizadorId;

  @override
  EstadoPublicacao build() {
    ref.onDispose(() => _descartado = true);
    _proporZona();
    return const EstadoPublicacao();
  }

  /// Propõe a zona do perfil. É só uma conveniência: se falhar, seja porquê
  /// for, o cliente escolhe a zona e nada mais é afectado.
  Future<void> _proporZona() async {
    try {
      final id = _clienteId;
      if (id == null) return;
      final zona = await ref.read(procuraRepositorioProvider).zonaDoCliente(id);
      if (!_descartado && zona != null && state.zonaId == null) {
        state = state.copiarCom(zonaId: zona);
      }
    } catch (_) {
      // Sem zona proposta, o cliente escolhe.
    }
  }

  /// Mudar de categoria limpa o serviço, que podia ser de outra.
  void escolherCategoria(String id) => state = state.copiarCom(
    categoriaId: id,
    limparServico: id != state.categoriaId,
    outroServico: id != state.categoriaId ? false : null,
    erros: {...state.erros}..remove('categoria'),
  );
  void escolherServico(String id) => state = state.copiarCom(
    servicoId: id,
    outroServico: false,
    erros: {...state.erros}..remove('servico'),
  );

  /// "Outro serviço": sem `servico_id`; o cliente descreve o que precisa.
  void escolherOutroServico() => state = state.copiarCom(
    limparServico: true,
    outroServico: true,
    erros: {...state.erros}..remove('servico'),
  );
  void escolherQuando(Urgencia u) => state = state.copiarCom(quando: u);
  void escolherZona(String id) => state = state.copiarCom(
    zonaId: id,
    erros: {...state.erros}..remove('zona'),
  );
  void limparErro(String campo) =>
      state = state.copiarCom(erros: {...state.erros}..remove(campo));

  Future<void> adicionarFoto(OrigemImagem origem) async {
    if (state.gravado || state.fotos.length >= maximoFotos) return;
    try {
      final foto = await ref.read(seletorImagemProvider).escolher(origem);
      if (foto != null && !_descartado) {
        state = state.copiarCom(fotos: [...state.fotos, foto]);
      }
    } catch (_) {
      state = state.copiarCom(
        erroEnvio:
            'Não foi possível abrir as fotografias. Autorize o acesso '
            'nas definições.',
      );
    }
  }

  void removerFoto(int i) {
    if (state.gravado) return;
    _comprimidas.clear();
    state = state.copiarCom(fotos: [...state.fotos]..removeAt(i));
  }

  static const outroServicoMinimo = 3;

  Future<void> publicar({
    required String titulo,
    required String descricao,
    required String orcamento,
    String outroServico = '',
  }) async {
    if (state.aEnviar || state.publicado) return;
    final clienteId = _clienteId;
    if (clienteId == null) {
      state = state.copiarCom(erroEnvio: 'Entre na sua conta para publicar.');
      return;
    }
    final valor = lerMt(orcamento);
    if (!state.gravado) {
      final erros = {
        if (titulo.trim().length < tituloMinimo)
          'titulo': 'Diga em poucas palavras o que precisa.',
        if (state.categoriaId == null) 'categoria': 'Escolha a categoria.',
        if (state.servicoId == null && !state.outroServico)
          'servico': 'Escolha o serviço.',
        if (state.outroServico &&
            outroServico.trim().length < outroServicoMinimo)
          'outro': 'Descreva o serviço de que precisa.',
        if (descricao.trim().length < descricaoMinima)
          'descricao': 'Descreva o trabalho em poucas palavras.',
        if (valor <= 0) 'orcamento': 'Indique o seu orçamento.',
        if (state.zonaId == null) 'zona': 'Escolha o bairro.',
      };
      if (erros.isNotEmpty) {
        state = state.copiarCom(erros: erros);
        return;
      }
    }

    state = state.copiarCom(aEnviar: true, limparErroEnvio: true);
    final repositorio = ref.read(concursosRepositorioProvider);
    try {
      if (!state.gravado && await _podiaProporASiProprio(clienteId)) {
        state = state.copiarCom(
          aEnviar: false,
          erroEnvio:
              'Presta este serviço nesta zona, por isso poderia responder ao '
              'seu próprio concurso. Escolha outra categoria ou outro bairro.',
        );
        return;
      }
      var id = state.concursoId;
      if (id == null) {
        state = state.copiarCom(etapa: 'A publicar o concurso…');
        id = await repositorio.publicar(
          NovoConcursoModelo(
            clienteId: clienteId,
            categoriaId: state.categoriaId!,
            servicoId: state.outroServico ? null : state.servicoId,
            titulo: titulo.trim(),
            descricao: state.outroServico
                ? textoComOutroServico(outroServico, descricao)
                : descricao.trim(),
            orcamento: valor,
            quando: state.quando,
            zonaId: state.zonaId!,
            fechaEm: DateTime.now().add(NovoConcursoModelo.duracao),
          ),
        );
        if (_descartado) return;
        state = state.copiarCom(concursoId: id);
      }
      final total = state.fotos.length;
      for (var i = 0; i < total; i++) {
        if (state.fotosEnviadas.contains(i)) continue;
        state = state.copiarCom(
          etapa: 'A enviar fotografia ${i + 1} de $total…',
        );
        final bytes = _comprimidas[i] ??= await ref
            .read(compressorImagemProvider)
            .comprimir(state.fotos[i].bytes)
            .catchError(
              (_) => throw const FalhaApp(
                'Não foi possível preparar uma das fotografias.',
              ),
            );
        await repositorio.anexar(
          clienteId: clienteId,
          concursoId: id,
          bytes: bytes,
        );
        if (_descartado) return;
        state = state.copiarCom(fotosEnviadas: {...state.fotosEnviadas, i});
      }
      state = state.copiarCom(
        aEnviar: false,
        limparEtapa: true,
        publicado: true,
      );
      ref.invalidate(meusConcursosProvider);
    } on FalhaApp catch (falha) {
      if (_descartado) return;
      state = state.copiarCom(
        aEnviar: false,
        limparEtapa: true,
        erroEnvio: state.gravado
            ? 'O concurso foi publicado, mas faltam fotografias. ${falha.mensagem}'
            : falha.mensagem,
      );
    }
  }

  void terminarSemFotografias() {
    if (!state.gravado || state.aEnviar) return;
    state = state.copiarCom(publicado: true, limparErroEnvio: true);
    ref.invalidate(meusConcursosProvider);
  }

  /// Quem publica também é prestador desta categoria e atende nesta zona:
  /// o concurso apareceria nas oportunidades dele.
  Future<bool> _podiaProporASiProprio(String clienteId) async {
    final categoria = await ref
        .read(prestadorRepositorioProvider)
        .obterCategoriaId(clienteId);
    if (categoria == null || categoria != state.categoriaId) return false;
    final zonas = await ref
        .read(concursosRepositorioProvider)
        .zonasDoPrestador(clienteId);
    return zonas.contains(state.zonaId);
  }
}

// ── Responder (tela 18) ────────────────────────────────────────────────────

@immutable
class EstadoResposta {
  const EstadoResposta({
    this.tipo = TipoProposta.contraproposta,
    this.erros = const {},
    this.aEnviar = false,
    this.erroEnvio,
    this.enviada = false,
  });

  final TipoProposta tipo;

  /// `valor`, `justificacao`.
  final Map<String, String> erros;
  final bool aEnviar;
  final String? erroEnvio;
  final bool enviada;
}

final respostaControladorProvider = NotifierProvider.autoDispose
    .family<RespostaControlador, EstadoResposta, String>(
      RespostaControlador.new,
    );

class RespostaControlador
    extends AutoDisposeFamilyNotifier<EstadoResposta, String> {
  @override
  EstadoResposta build(String concursoId) => const EstadoResposta();

  void escolherTipo(TipoProposta tipo) => state = EstadoResposta(tipo: tipo);

  void limparErro(String campo) => state = EstadoResposta(
    tipo: state.tipo,
    erros: {...state.erros}..remove(campo),
  );

  /// Envia a proposta. A justificação da contraproposta é validada aqui
  /// (mínimo de 15 caracteres, a mesma restrição da base), para o
  /// utilizador não levar com um erro do servidor.
  Future<void> enviar({
    required ConcursoModelo concurso,
    required String valorTexto,
    required String justificacao,
  }) async {
    if (state.aEnviar || state.enviada) return;
    final prestadorId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (prestadorId == null) {
      state = EstadoResposta(
        tipo: state.tipo,
        erroEnvio: 'Entre na sua conta de prestador para responder.',
      );
      return;
    }
    if (concurso.clienteId == prestadorId) {
      state = EstadoResposta(
        tipo: state.tipo,
        erroEnvio: 'Não pode responder a um concurso seu.',
      );
      return;
    }
    final texto = justificacao.trim();
    final contra = state.tipo == TipoProposta.contraproposta;
    final valor = contra ? lerMt(valorTexto) : concurso.orcamento ?? 0;
    final erros = {
      if (contra && valor <= 0) 'valor': 'Indique o seu valor.',
      if (contra && texto.length < NovaPropostaModelo.justificacaoMinima)
        'justificacao':
            'Explique o valor em pelo menos '
            '${NovaPropostaModelo.justificacaoMinima} caracteres.',
      if (!contra && valor <= 0)
        'valor': 'Este concurso não tem orçamento; faça uma contraproposta.',
    };
    if (erros.isNotEmpty) {
      state = EstadoResposta(tipo: state.tipo, erros: erros);
      return;
    }

    state = EstadoResposta(tipo: state.tipo, aEnviar: true);
    try {
      await ref
          .read(concursosRepositorioProvider)
          .responder(
            NovaPropostaModelo(
              concursoId: arg,
              prestadorId: prestadorId,
              tipo: state.tipo,
              valor: valor,
              justificacao: texto.isEmpty ? null : texto,
            ),
          );
      state = EstadoResposta(tipo: state.tipo, enviada: true);
      ref.invalidate(oportunidadesProvider);
    } on FalhaApp catch (falha) {
      state = EstadoResposta(
        tipo: state.tipo,
        erroEnvio: falha.mensagem == 'Este registo já existe.'
            ? 'Já respondeu a este concurso.'
            : falha.mensagem,
      );
    }
  }
}

// ── Escolher (tela 19) ─────────────────────────────────────────────────────

/// O `id` da proposta a ser adjudicada, ou `null`.
final adjudicacaoControladorProvider =
    NotifierProvider.autoDispose<AdjudicacaoControlador, String?>(
      AdjudicacaoControlador.new,
    );

class AdjudicacaoControlador extends AutoDisposeNotifier<String?> {
  @override
  String? build() => null;

  /// Chama `adjudicar_concurso`. Devolve a mensagem de erro, ou `null`.
  Future<String?> escolher(String concursoId, String propostaId) async {
    if (state != null) return null;
    state = propostaId;
    try {
      await ref.read(concursosRepositorioProvider).adjudicar(propostaId);
      ref
        ..invalidate(propostasProvider(concursoId))
        ..invalidate(concursoProvider(concursoId))
        ..invalidate(meusConcursosProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = null;
    }
  }
}

// ── Apresentação ───────────────────────────────────────────────────────────

/// "Fecha em 18 h", "Fecha em 2 dias", "Fechado".
String textoFecho(DateTime? fechaEm, DateTime agora) {
  if (fechaEm == null) return '';
  final falta = fechaEm.difference(agora);
  if (falta.isNegative) return 'Fechado';
  if (falta.inHours < 1) return 'Fecha em ${falta.inMinutes} min';
  if (falta.inHours < 48) return 'Fecha em ${falta.inHours} h';
  return 'Fecha em ${falta.inDays} dias';
}

String textoOrcamento(int? valor) =>
    valor == null ? 'Sem orçamento' : '${formatarMt(valor)} MT';

/// Com "Outro serviço", o que o cliente escreveu abre o texto do concurso,
/// para os prestadores saberem o que se pede sem `servico_id`.
String textoComOutroServico(String outroServico, String descricao) =>
    'Serviço pedido: ${outroServico.trim()}.\n\n${descricao.trim()}';
