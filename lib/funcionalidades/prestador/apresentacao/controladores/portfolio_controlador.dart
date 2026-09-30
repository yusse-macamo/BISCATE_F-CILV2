import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/portfolio_repositorio.dart';

/// O portefólio do prestador autenticado (tela 12).
final meuPortfolioProvider =
    FutureProvider.autoDispose<List<ItemPortfolioModelo>>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para ver o seu portefólio.');
      }
      return ref.watch(portfolioRepositorioProvider).listar(id);
    });

/// Acrescentar fotografias. O estado diz se há uma a caminho.
final portfolioControladorProvider =
    NotifierProvider.autoDispose<PortfolioControlador, bool>(
      PortfolioControlador.new,
    );

class PortfolioControlador extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  /// Escolhe, comprime e envia uma fotografia. Devolve a mensagem de erro,
  /// ou `null` se correu bem (ou se o utilizador desistiu).
  Future<String?> adicionarFoto(OrigemImagem origem) async {
    if (state) return null;
    final prestadorId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (prestadorId == null) return 'Entre na sua conta para publicar.';

    final ImagemEscolhida? imagem;
    try {
      imagem = await ref.read(seletorImagemProvider).escolher(origem);
    } catch (_) {
      return 'Não foi possível abrir as fotografias. Autorize o acesso nas '
          'definições.';
    }
    if (imagem == null) return null;

    state = true;
    try {
      final bytes = await ref
          .read(compressorImagemProvider)
          .comprimir(imagem.bytes)
          .catchError(
            (_) =>
                throw const FalhaApp('Não foi possível preparar a fotografia.'),
          );
      await ref
          .read(portfolioRepositorioProvider)
          .adicionarFoto(prestadorId: prestadorId, bytes: bytes);
      ref.invalidate(meuPortfolioProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = false;
    }
  }
}
