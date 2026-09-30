import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../cliente/apresentacao/widgets/foto_prestador.dart';
import '../../dados/repositorios/portfolio_repositorio.dart';
import '../controladores/portfolio_controlador.dart';

/// 12 · Portfólio
///
/// Lê `portfolio` do próprio e acrescenta fotografias (comprimidas, no
/// bucket `publico`). Os vídeos só se mostram: o envio de vídeo ainda não
/// existe na app.
class EcraPortfolio extends ConsumerStatefulWidget {
  const EcraPortfolio({super.key});

  @override
  ConsumerState<EcraPortfolio> createState() => _EstadoEcraPortfolio();
}

class _EstadoEcraPortfolio extends ConsumerState<EcraPortfolio> {
  int _separador = 0;

  Future<void> _adicionar() async {
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: 'Novo trabalho',
    );
    if (opcao == null || !mounted) return;
    final erro = await ref
        .read(portfolioControladorProvider.notifier)
        .adicionarFoto(
          opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria,
        );
    if (erro != null && mounted) mostrarAviso(context, erro);
  }

  @override
  Widget build(BuildContext context) {
    final itens = ref.watch(meuPortfolioProvider);
    final aEnviar = ref.watch(portfolioControladorProvider);
    final todos = itens.valueOrNull ?? const <ItemPortfolioModelo>[];
    final fotos = todos.where((i) => i.tipo == TipoMedia.foto).toList();
    final videos = todos.where((i) => i.tipo == TipoMedia.video).toList();
    final mostrados = _separador == 0 ? fotos : videos;

    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: comEspaco([
          const LinhaTitulo(titulo: 'Portfólio'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CoresApp.verdeClaro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Perfis com 6 ou mais fotos recebem mais pedidos. Mostre o antes e depois.',
              style: estiloTexto(13, c: CoresApp.verdeEscuro, h: 1.4),
            ),
          ),
          Segmentado(
            altura: 38,
            rotulos: itens.hasValue
                ? ['Fotos (${fotos.length})', 'Vídeos (${videos.length})']
                : const ['Fotos', 'Vídeos'],
            indice: _separador,
            aoMudar: (i) => setState(() => _separador = i),
          ),
          itens.when(
            loading: () => const EstadoCarregar(),
            error: (erro, _) => EstadoErro(
              mensagem: mensagemDe(erro),
              aoRepetir: () => ref.invalidate(meuPortfolioProvider),
            ),
            data: (_) => GrelhaUniforme(
              colunas: 2,
              children: [
                if (_separador == 0)
                  AspectRatio(
                    aspectRatio: 1,
                    child: CaixaTracejada(
                      raio: 14,
                      aoTocar: aEnviar ? null : _adicionar,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            aEnviar ? '…' : '+',
                            style: estiloTexto(26, c: CoresApp.atenuado),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            aEnviar ? 'A enviar' : 'Adicionar',
                            style: estiloTexto(
                              13,
                              w: w700,
                              c: CoresApp.atenuado,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final item in mostrados)
                  AspectRatio(
                    aspectRatio: 1,
                    child: item.tipo == TipoMedia.foto
                        ? FotoPrestador(url: item.url)
                        : Riscado(
                            raio: 14,
                            banda: 6,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  item.legenda ?? 'vídeo',
                                  style: mono(10),
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          if (itens.hasValue && _separador == 1 && videos.isEmpty)
            const EstadoVazio(
              'Ainda não tem vídeos. O envio de vídeos chega numa próxima '
              'versão.',
            ),
        ], 14),
      ),
    );
  }
}
