import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/portfolio_repositorio.dart';

/// A galeria do prestador autenticado.
final meuPortfolioProvider =
    FutureProvider.autoDispose<List<FotoPortfolioModelo>>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para ver a sua galeria.');
      }
      return ref.watch(portfolioRepositorioProvider).listar(id);
    });

@immutable
class EstadoGaleria {
  const EstadoGaleria({this.aEnviar = false, this.aRemover = const {}});

  final bool aEnviar;

  /// `id` das fotografias a ser removidas.
  final Set<String> aRemover;
}

final galeriaControladorProvider =
    NotifierProvider.autoDispose<GaleriaControlador, EstadoGaleria>(
      GaleriaControlador.new,
    );

class GaleriaControlador extends AutoDisposeNotifier<EstadoGaleria> {
  static const limiteFotos = 10;
  static const legendaMaxima = 80;

  @override
  EstadoGaleria build() => const EstadoGaleria();

  String? get _prestadorId =>
      ref.read(autenticacaoRepositorioProvider).utilizadorId;

  /// `null` se ainda se pode acrescentar; senão, a razão.
  String? podeAcrescentar(int quantas) => quantas >= limiteFotos
      ? 'A galeria tem o máximo de $limiteFotos fotografias. Remova uma para '
            'acrescentar outra.'
      : null;

  /// Abre a câmara ou a galeria do telefone. `null` se desistiu.
  Future<ImagemEscolhida?> escolher(OrigemImagem origem) async {
    try {
      return await ref.read(seletorImagemProvider).escolher(origem);
    } catch (_) {
      throw const FalhaApp(
        'Não foi possível abrir as fotografias. Autorize o acesso nas '
        'definições.',
      );
    }
  }

  /// Comprime (largura máxima de 1600 px) e publica. A legenda é opcional.
  /// Devolve a mensagem de erro, ou `null` se correu bem.
  Future<String?> publicar(
    ImagemEscolhida imagem, {
    required List<FotoPortfolioModelo> actuais,
    String? legenda,
  }) async {
    if (state.aEnviar) return null;
    final prestadorId = _prestadorId;
    if (prestadorId == null) return 'Entre na sua conta para publicar.';
    if (podeAcrescentar(actuais.length) case final motivo?) return motivo;
    final texto = legenda?.trim() ?? '';
    if (texto.length > legendaMaxima) {
      return 'A legenda pode ter até $legendaMaxima caracteres.';
    }

    state = EstadoGaleria(aEnviar: true, aRemover: state.aRemover);
    try {
      final Uint8List bytes;
      try {
        bytes = await ref
            .read(compressorImagemProvider)
            .comprimir(imagem.bytes);
      } catch (_) {
        throw const FalhaApp('Não foi possível preparar a fotografia.');
      }
      // A nova fotografia fica no fim da galeria.
      final ultima = actuais.fold<int>(
        0,
        (maior, f) => (f.ordem ?? 0) > maior ? f.ordem! : maior,
      );
      await ref
          .read(portfolioRepositorioProvider)
          .adicionarFoto(
            prestadorId: prestadorId,
            bytes: bytes,
            ordem: ultima + 1,
            legenda: texto.isEmpty ? null : texto,
          );
      ref.invalidate(meuPortfolioProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = EstadoGaleria(aRemover: state.aRemover);
    }
  }

  /// Devolve a mensagem de erro, ou `null` se correu bem.
  Future<String?> remover(FotoPortfolioModelo foto) async {
    if (state.aRemover.contains(foto.id)) return null;
    state = EstadoGaleria(
      aEnviar: state.aEnviar,
      aRemover: {...state.aRemover, foto.id},
    );
    try {
      await ref.read(portfolioRepositorioProvider).remover(foto);
      ref.invalidate(meuPortfolioProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = EstadoGaleria(
        aEnviar: state.aEnviar,
        aRemover: {...state.aRemover}..remove(foto.id),
      );
    }
  }
}
