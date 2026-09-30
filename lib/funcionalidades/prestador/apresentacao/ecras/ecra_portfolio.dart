import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../cliente/apresentacao/widgets/foto_prestador.dart';
import '../../dados/repositorios/portfolio_repositorio.dart';
import '../controladores/portfolio_controlador.dart';

/// 12 · Galeria de trabalhos
///
/// Fotografias em `portfolio`, ficheiros no bucket `publico`. Até 10, com
/// legenda opcional. Só fotografias nesta fase.
class EcraPortfolio extends ConsumerWidget {
  const EcraPortfolio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(meuPortfolioProvider);
    final quantas = fotos.valueOrNull?.length;
    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: comEspaco([
          LinhaTitulo(
            titulo: 'Galeria de trabalhos',
            subtitulo: quantas == null
                ? null
                : '$quantas de ${GaleriaControlador.limiteFotos} fotografias',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CoresApp.verdeClaro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Perfis com 6 ou mais fotos recebem mais pedidos. Mostre o antes '
              'e depois. Os clientes vêem a galeria no seu perfil.',
              style: estiloTexto(13, c: CoresApp.verdeEscuro, h: 1.4),
            ),
          ),
          fotos.when(
            loading: () => const EstadoCarregar(),
            error: (erro, _) => EstadoErro(
              mensagem: mensagemDe(erro),
              aoRepetir: () => ref.invalidate(meuPortfolioProvider),
            ),
            data: (lista) => _Grelha(lista),
          ),
        ], 14),
      ),
    );
  }
}

class _Grelha extends ConsumerWidget {
  const _Grelha(this.fotos);

  final List<FotoPortfolioModelo> fotos;

  Future<void> _acrescentar(BuildContext context, WidgetRef ref) async {
    final controlador = ref.read(galeriaControladorProvider.notifier);
    if (controlador.podeAcrescentar(fotos.length) case final motivo?) {
      return mostrarAviso(context, motivo);
    }
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: 'Novo trabalho',
    );
    if (opcao == null || !context.mounted) return;

    final ImagemEscolhida? imagem;
    try {
      imagem = await controlador.escolher(
        opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria,
      );
    } on FalhaApp catch (falha) {
      if (context.mounted) mostrarAviso(context, falha.mensagem);
      return;
    }
    if (imagem == null || !context.mounted) return;

    final resposta = await showModalBottomSheet<({String legenda})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CoresApp.pagina,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FolhaLegenda(imagem!),
    );
    if (resposta == null || !context.mounted) return;
    final erro = await controlador.publicar(
      imagem,
      actuais: fotos,
      legenda: resposta.legenda,
    );
    if (context.mounted) {
      mostrarAviso(context, erro ?? 'Fotografia publicada na sua galeria.');
    }
  }

  Future<void> _remover(
    BuildContext context,
    WidgetRef ref,
    FotoPortfolioModelo foto,
  ) async {
    final confirmado = await escolherOpcao(
      context,
      const ['Remover fotografia', 'Cancelar'],
      '',
      titulo: 'Remover esta fotografia da galeria?',
    );
    if (confirmado != 'Remover fotografia' || !context.mounted) return;
    final erro = await ref
        .read(galeriaControladorProvider.notifier)
        .remover(foto);
    if (erro != null && context.mounted) mostrarAviso(context, erro);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(galeriaControladorProvider);
    final cheia = fotos.length >= GaleriaControlador.limiteFotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrelhaUniforme(
          colunas: 2,
          children: [
            if (!cheia)
              AspectRatio(
                aspectRatio: 1,
                child: CaixaTracejada(
                  raio: 14,
                  aoTocar: estado.aEnviar
                      ? null
                      : () => _acrescentar(context, ref),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        estado.aEnviar ? '…' : '+',
                        style: estiloTexto(26, c: CoresApp.atenuado),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estado.aEnviar ? 'A publicar' : 'Acrescentar',
                        style: estiloTexto(13, w: w700, c: CoresApp.atenuado),
                      ),
                    ],
                  ),
                ),
              ),
            for (final foto in fotos)
              _Miniatura(
                foto,
                aRemover: estado.aRemover.contains(foto.id),
                aoRemover: () => _remover(context, ref, foto),
              ),
          ],
        ),
        if (fotos.isEmpty) ...[
          const SizedBox(height: 12),
          const EstadoVazio(
            'Ainda não publicou trabalhos. Comece pelas fotografias de que '
            'mais se orgulha.',
          ),
        ],
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura(
    this.foto, {
    required this.aRemover,
    required this.aoRemover,
  });

  final FotoPortfolioModelo foto;
  final bool aRemover;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: aRemover ? 0.4 : 1,
            child: FotoPrestador(url: foto.url),
          ),
          if (foto.legenda case final legenda? when legenda.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: .55),
                    ],
                  ),
                ),
                child: Text(
                  legenda,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: estiloTexto(12, w: w700, c: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Semantics(
              button: true,
              label: 'Remover fotografia',
              child: Toque(
                raio: 14,
                aoTocar: aRemover ? null : aoRemover,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    aRemover ? '…' : '✕',
                    style: estiloTexto(13, w: w800, c: CoresApp.rejeitar),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pré-visualização e legenda opcional antes de publicar.
class _FolhaLegenda extends StatefulWidget {
  const _FolhaLegenda(this.imagem);

  final ImagemEscolhida imagem;

  @override
  State<_FolhaLegenda> createState() => _EstadoFolhaLegenda();
}

class _EstadoFolhaLegenda extends State<_FolhaLegenda> {
  final _legenda = TextEditingController();

  @override
  void dispose() {
    _legenda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo trabalho', style: estiloTexto(18, w: w800)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                widget.imagem.bytes,
                height: 180,
                fit: BoxFit.cover,
                cacheHeight: 540,
              ),
            ),
            const SizedBox(height: 14),
            ComRotulo(
              rotulo: 'Legenda',
              dica: '(opcional)',
              child: CampoTexto(
                controlador: _legenda,
                textoDica: 'Ex.: Quadro eléctrico, antes e depois',
              ),
            ),
            const SizedBox(height: 16),
            BotaoPrimario(
              'Publicar',
              aoTocar: () => Navigator.pop(context, (legenda: _legenda.text)),
            ),
          ],
        ),
      ),
    );
  }
}
