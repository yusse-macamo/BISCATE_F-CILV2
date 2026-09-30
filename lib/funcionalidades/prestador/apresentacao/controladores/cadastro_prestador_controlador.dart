import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/modelos/novo_prestador_modelo.dart';
import '../../dados/repositorios/prestador_repositorio.dart';
import 'cadastro_prestador_estado.dart';

final cadastroPrestadorControladorProvider =
    NotifierProvider.autoDispose<
      CadastroPrestadorControlador,
      CadastroPrestadorEstado
    >(CadastroPrestadorControlador.new);

class CadastroPrestadorControlador
    extends AutoDisposeNotifier<CadastroPrestadorEstado> {
  static const maximoAnos = 60;
  static const maximoBio = 500;

  /// Fotografias já comprimidas, para que repetir o envio não volte a
  /// comprimir. Sai daqui a de um documento que se troque ou remova.
  final _comprimidas = <TipoDocumento, Uint8List>{};

  @override
  CadastroPrestadorEstado build() => const CadastroPrestadorEstado();

  // ── Passo 1: serviço ────────────────────────────────────────────────────

  void escolherCategoria(String categoriaId) => state = state.copiarCom(
    categoriaId: categoriaId,
    erros: _semErro('categoria'),
  );

  void definirBio(String bio) => state = state.copiarCom(bio: bio);

  void definirAnos(String anos) =>
      state = state.copiarCom(anos: anos, erros: _semErro('anos'));

  // ── Passo 2: zonas ──────────────────────────────────────────────────────

  void alternarZona(String zonaId) {
    final zonas = {...state.zonas};
    if (!zonas.remove(zonaId)) zonas.add(zonaId);
    state = state.copiarCom(zonas: zonas, erros: _semErro('zonas'));
  }

  // ── Passo 3: documentos ─────────────────────────────────────────────────

  Future<void> escolherDocumento(
    TipoDocumento tipo,
    OrigemImagem origem,
  ) async {
    final ImagemEscolhida? imagem;
    try {
      imagem = await ref.read(seletorImagemProvider).escolher(origem);
    } catch (e, stackTrace) {
      debugPrint('ERRO CADASTRO: $e');
      debugPrint('$stackTrace');
      // Normalmente, permissão de câmara ou de fotografias recusada.
      state = state.copiarCom(
        erros: {
          ...state.erros,
          'documentos': origem == OrigemImagem.camara
              ? 'Não foi possível abrir a câmara. Autorize o acesso nas '
                    'definições ou escolha da galeria.'
              : 'Não foi possível abrir as fotografias. Autorize o acesso '
                    'nas definições.',
        },
      );
      return;
    }
    if (imagem == null) return;
    _esquecerEnvioDe(tipo);
    state = state.copiarCom(
      documentos: {...state.documentos, tipo: imagem},
      erros: _semErro('documentos'),
    );
  }

  void removerDocumento(TipoDocumento tipo) {
    _esquecerEnvioDe(tipo);
    state = state.copiarCom(documentos: {...state.documentos}..remove(tipo));
  }

  // ── Navegação entre passos ──────────────────────────────────────────────

  /// Valida o passo actual e avança. No passo dos documentos, começa o envio.
  /// Devolve `false` se ficou no mesmo passo por haver erros.
  bool avancar() {
    final erros = _validar(state.passo);
    if (erros.isNotEmpty) {
      state = state.copiarCom(erros: erros);
      return false;
    }
    final seguinte = PassoCadastroPrestador.values[state.passo.index + 1];
    state = state.copiarCom(passo: seguinte, erros: const {});
    if (seguinte == PassoCadastroPrestador.envio) _enviar();
    return true;
  }

  /// Recua um passo. Devolve `false` quando não há para onde recuar e o ecrã
  /// deve fechar, ou quando está a enviar ou o registo já foi gravado (a
  /// partir daí só se pode repetir o que falta).
  bool recuar() {
    if (state.passo == PassoCadastroPrestador.servico) return false;
    if (state.aEnviar ||
        state.enviado ||
        state.etapasConcluidas.contains(EtapaEnvio.registo)) {
      return false;
    }
    state = state.copiarCom(
      passo: PassoCadastroPrestador.values[state.passo.index - 1],
      erros: const {},
      limparErroEnvio: true,
    );
    return true;
  }

  /// Repete o envio a partir da etapa que falhou.
  Future<void> repetirEnvio() => _enviar();

  // ── Envio ───────────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    if (state.aEnviar) return;
    // Diagnóstico: o que o servidor vê como utilizador. Num try próprio, para
    // não mudar o fluxo do envio se a função não existir.
    try {
      final r = await Supabase.instance.client.rpc('quem_sou');
      debugPrint('QUEM SOU: $r');
    } catch (e) {
      debugPrint('QUEM SOU falhou: $e');
    }
    final perfilId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (perfilId == null) {
      state = state.copiarCom(
        erroEnvio: 'Entre na sua conta antes de se registar como prestador.',
      );
      return;
    }

    state = state.copiarCom(aEnviar: true, limparErroEnvio: true);
    try {
      for (final etapa in state.etapas) {
        if (state.etapasConcluidas.contains(etapa)) continue;
        state = state.copiarCom(etapaActual: etapa);
        await _correr(etapa, perfilId);
        state = state.copiarCom(
          etapasConcluidas: {...state.etapasConcluidas, etapa},
        );
      }
      state = state.copiarCom(
        aEnviar: false,
        limparEtapaActual: true,
        enviado: true,
      );
      // O encaminhamento passa a levar este utilizador ao ecrã de aguardo.
      ref.invalidate(destinoInicialProvider);
    } catch (e, stackTrace) {
      debugPrint('ERRO CADASTRO: $e');
      debugPrint('$stackTrace');
      state = state.copiarCom(aEnviar: false, erroEnvio: mensagemDe(e));
    }
  }

  Future<void> _correr(EtapaEnvio etapa, String perfilId) async {
    final repositorio = ref.read(prestadorRepositorioProvider);
    switch (etapa) {
      case EtapaEnvio.preparar:
        await _comprimirDocumentos();
      case EtapaEnvio.fotoPerfil:
        debugPrint('ETAPA: foto de perfil');
        await _carregar(
          repositorio,
          perfilId,
          TipoDocumento.fotoPerfil,
          BucketsPrestador.publico,
        );
      case EtapaEnvio.fotoNoPerfil:
        debugPrint('ETAPA: update de perfis.foto');
        await repositorio.gravarFotoPerfil(
          perfilId: perfilId,
          caminho: state.caminhos[TipoDocumento.fotoPerfil]!,
        );
      case EtapaEnvio.biFrente:
        debugPrint('ETAPA: BI frente');
        await _carregar(
          repositorio,
          perfilId,
          TipoDocumento.biFrente,
          BucketsPrestador.documentos,
        );
      case EtapaEnvio.biVerso:
        debugPrint('ETAPA: BI verso');
        await _carregar(
          repositorio,
          perfilId,
          TipoDocumento.biVerso,
          BucketsPrestador.documentos,
        );
      case EtapaEnvio.registo:
        debugPrint('ETAPA: insert em prestadores');
        final bio = state.bio.trim();
        await repositorio.registar(
          NovoPrestadorModelo(
            perfilId: perfilId,
            categoriaId: state.categoriaId!,
            bio: bio.isEmpty ? null : bio,
            anosExperiencia: int.tryParse(state.anos.trim()),
          ),
        );
      case EtapaEnvio.documentos:
        debugPrint('ETAPA: insert em documentos');
        await repositorio.registarDocumentos(
          perfilId: perfilId,
          caminhosPorTipo: {
            for (final tipo in [TipoDocumento.biFrente, TipoDocumento.biVerso])
              tipo.nomeFicheiro: ?state.caminhos[tipo],
          },
        );
      case EtapaEnvio.zonas:
        debugPrint('ETAPA: insert em prestador_zonas');
        await repositorio.associarZonas(
          perfilId: perfilId,
          zonaIds: state.zonas,
        );
    }
  }

  Future<void> _comprimirDocumentos() async {
    final compressor = ref.read(compressorImagemProvider);
    try {
      for (final MapEntry(key: tipo, value: imagem)
          in state.documentos.entries) {
        _comprimidas[tipo] ??= await compressor.comprimir(imagem.bytes);
      }
    } catch (e, stackTrace) {
      debugPrint('ERRO CADASTRO: $e');
      debugPrint('$stackTrace');
      throw const FalhaApp(
        'Não foi possível preparar as fotografias. Volte atrás e escolha-as '
        'de novo.',
      );
    }
  }

  /// Envia e guarda o caminho devolvido, para o gravar na base.
  Future<void> _carregar(
    PrestadorRepositorio repositorio,
    String perfilId,
    TipoDocumento tipo,
    String bucket,
  ) async {
    final caminho = await repositorio.carregarImagem(
      bucket: bucket,
      perfilId: perfilId,
      tipo: tipo.nomeFicheiro,
      bytes: _comprimidas[tipo]!,
    );
    state = state.copiarCom(caminhos: {...state.caminhos, tipo: caminho});
  }

  // ── Regras ──────────────────────────────────────────────────────────────

  Map<String, String> _validar(PassoCadastroPrestador passo) {
    switch (passo) {
      case PassoCadastroPrestador.servico:
        final anos = state.anos.trim();
        final numero = int.tryParse(anos);
        return {
          if (state.categoriaId == null)
            'categoria': 'Escolha o serviço que presta.',
          if (anos.isNotEmpty &&
              (numero == null || numero < 0 || numero > maximoAnos))
            'anos': 'Indique um número de anos entre 0 e $maximoAnos.',
          if (state.bio.trim().length > maximoBio)
            'bio': 'Escreva no máximo $maximoBio caracteres.',
        };
      case PassoCadastroPrestador.zonas:
        return {
          if (state.zonas.isEmpty)
            'zonas': 'Escolha pelo menos uma zona onde atende.',
        };
      case PassoCadastroPrestador.documentos:
        final semFoto = !state.documentos.containsKey(TipoDocumento.fotoPerfil);
        final semBi = !state.documentos.containsKey(TipoDocumento.biFrente);
        return {
          if (semFoto && semBi)
            'documentos': 'Faltam a foto de perfil e a frente do BI.'
          else if (semFoto)
            'documentos': 'Falta a foto de perfil.'
          else if (semBi)
            'documentos': 'Falta a frente do BI.',
        };
      case PassoCadastroPrestador.envio:
        return const {};
    }
  }

  /// Um documento trocado ou removido tem de voltar a ser comprimido e
  /// enviado, mesmo que a versão anterior já tenha subido.
  void _esquecerEnvioDe(TipoDocumento tipo) {
    _comprimidas.remove(tipo);
    final etapa = switch (tipo) {
      TipoDocumento.fotoPerfil => EtapaEnvio.fotoPerfil,
      TipoDocumento.biFrente => EtapaEnvio.biFrente,
      TipoDocumento.biVerso => EtapaEnvio.biVerso,
    };
    state = state.copiarCom(
      caminhos: {...state.caminhos}..remove(tipo),
      etapasConcluidas: {...state.etapasConcluidas}
        ..remove(EtapaEnvio.preparar)
        ..remove(etapa)
        // Uma foto nova tem de voltar a ser gravada no perfil.
        ..removeAll([
          if (tipo == TipoDocumento.fotoPerfil) EtapaEnvio.fotoNoPerfil,
        ]),
    );
  }

  Map<String, String> _semErro(String campo) => {...state.erros}..remove(campo);
}
