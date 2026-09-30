import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../prestador/dados/repositorios/portfolio_repositorio.dart';
import '../../dados/modelos/prestador_publico_modelo.dart';
import '../../dados/repositorios/avaliacoes_repositorio.dart';
import '../controladores/perfil_prestador_controlador.dart';
import '../controladores/procura_controlador.dart';
import '../widgets/foto_prestador.dart';
import 'ecra_solicitacao.dart';

/// 06 · Perfil do prestador
///
/// Dados, estatísticas e preços vêm de `prestadores` + `perfis` +
/// `precos_prestador`; o favorito, de `favoritos`. O portefólio e as
/// avaliações continuam de exemplo até esses passos serem ligados.
class EcraPerfilPrestador extends ConsumerWidget {
  const EcraPerfilPrestador({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(perfilPrestadorProvider(prestadorId))
        .when(
          loading: () => const EcraBase(
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
                Expanded(child: EstadoCarregar()),
              ],
            ),
          ),
          error: (erro, _) => EcraBase(
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BotaoVoltar(),
                ),
                Expanded(
                  child: EstadoErro(
                    mensagem: mensagemDe(erro),
                    aoRepetir: () =>
                        ref.invalidate(perfilPrestadorProvider(prestadorId)),
                  ),
                ),
              ],
            ),
          ),
          data: (p) => p == null
              ? const EcraBase(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BotaoVoltar(),
                      ),
                      Expanded(
                        child: EstadoVazio(
                          'Este prestador não está disponível de momento.',
                        ),
                      ),
                    ],
                  ),
                )
              : _Perfil(p),
        );
  }
}

class _Perfil extends ConsumerWidget {
  const _Perfil(this.p);

  final PrestadorPublicoModelo p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topo = MediaQuery.paddingOf(context).top;
    final favorito =
        ref.watch(favoritoProvider(p.perfilId)).valueOrNull ?? false;
    final avaliacao = textoAvaliacao(p);
    final subtitulo = [
      ?p.descricao,
      if (p.zonas.isNotEmpty) p.zonas.join(', '),
      if (p.anosExperiencia case final anos? when anos > 0)
        anos == 1 ? '1 ano de experiência' : '$anos anos de experiência',
    ].join(' · ');
    // Um prestador não pede serviço a si próprio (a base também o impede).
    final proprio =
        p.perfilId == ref.read(autenticacaoRepositorioProvider).utilizadorId;

    return EcraBase(
      topoSeguro: false,
      barraInferior: proprio
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: CoresApp.borda)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Text(
                    'Este é o seu perfil, tal como os clientes o vêem.',
                    textAlign: TextAlign.center,
                    style: estiloTexto(13.5, c: CoresApp.atenuado),
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: CoresApp.borda)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                  child: Row(
                    children: [
                      BotaoContorno(
                        'Ligar',
                        largura: 52,
                        altura: 52,
                        tamanhoFonte: 12,
                        aoTocar: () =>
                            mostrarAviso(context, 'A ligar para ${p.nome}…'),
                      ),
                      const SizedBox(width: 10),
                      BotaoContorno(
                        'WhatsApp',
                        largura: 52,
                        altura: 52,
                        tamanhoFonte: 10.5,
                        aoTocar: () =>
                            mostrarAviso(context, 'A abrir WhatsApp…'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BotaoPrimario(
                          'Solicitar serviço',
                          altura: 52,
                          tamanhoFonte: 15,
                          aoTocar: () => navegarPara(
                            context,
                            EcraSolicitacao(
                              prestadorId: p.perfilId,
                              nomePrestador: p.nome,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topo, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BotaoVoltar(tamanho: 40),
                Toque(
                  aoTocar: () async {
                    final erro = await ref
                        .read(favoritoProvider(p.perfilId).notifier)
                        .alternar();
                    if (erro != null && context.mounted) {
                      mostrarAviso(context, erro);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CoresApp.borda),
                    ),
                    child: Text(
                      favorito ? '♥' : '♡',
                      style: estiloTexto(
                        16,
                        c: favorito ? CoresApp.rejeitar : CoresApp.tinta,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: comEspaco([
                Align(
                  alignment: Alignment.centerLeft,
                  child: FotoPrestador(
                    url: p.fotoUrl,
                    largura: 84,
                    altura: 84,
                    raio: 20,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nome, style: estiloTexto(24, w: w800, ls: -0.01)),
                    if (subtitulo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: estiloTexto(14, c: CoresApp.atenuado),
                      ),
                    ],
                  ],
                ),
                if (p.verificado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: CoresApp.verdeClaro,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const PontoVerificado(tamanho: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Identidade verificada\n',
                                  style: estiloTexto(
                                    13,
                                    w: w700,
                                    c: CoresApp.verdeEscuro,
                                    h: 1.35,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'BI e morada confirmados pela Biscate Fácil',
                                  style: estiloTexto(
                                    13,
                                    c: CoresApp.verdeEscuro,
                                    h: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CoresApp.borda),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _estatistica(
                          avaliacao == null
                              ? Text('—', style: estiloTexto(18, w: w800))
                              : Text.rich(
                                  spanEstrela(avaliacao, tamanho: 18, w: w800),
                                ),
                          p.totalAvaliacoes == 1
                              ? '1 avaliação'
                              : '${p.totalAvaliacoes} avaliações',
                        ),
                        const VerticalDivider(width: 1, color: CoresApp.borda),
                        _estatistica(
                          Text(
                            '${p.servicosFeitos}',
                            style: estiloTexto(18, w: w800),
                          ),
                          'serviços feitos',
                        ),
                        const VerticalDivider(width: 1, color: CoresApp.borda),
                        _estatistica(
                          Text(
                            p.pctRecomenda == null
                                ? '—'
                                : '${p.pctRecomenda!.round()}%',
                            style: estiloTexto(18, w: w800),
                          ),
                          'recomendam',
                        ),
                      ],
                    ),
                  ),
                ),
                if (p.bio case final bio? when bio.trim().isNotEmpty)
                  Text(bio, style: estiloTexto(14, c: CoresApp.corpo, h: 1.55)),
                _cabecalho('Preços'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CoresApp.borda),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (p.precos.isEmpty)
                        const EstadoVazio('Ainda não indicou preços.'),
                      for (final preco in p.precos)
                        LinhaChaveValor(
                          rotulo: preco.servico,
                          valor: Text(
                            textoPreco(preco.valor),
                            style: estiloTexto(14, w: w700),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          'Preços iniciais. O valor final é combinado antes do serviço.',
                          style: estiloTexto(12, c: CoresApp.atenuado),
                        ),
                      ),
                    ],
                  ),
                ),
                _cabecalho('Galeria de trabalhos'),
                VistaLista<FotoPortfolioModelo>(
                  valor: ref.watch(portfolioPrestadorProvider(p.perfilId)),
                  aoRepetir: () =>
                      ref.invalidate(portfolioPrestadorProvider(p.perfilId)),
                  mensagemVazia: 'Ainda não publicou trabalhos.',
                  construir: (fotos) => GrelhaUniforme(
                    colunas: 3,
                    espacoH: 8,
                    children: [
                      for (final foto in fotos)
                        AspectRatio(
                          aspectRatio: 1,
                          child: Toque(
                            aoTocar: () => _verFoto(context, foto),
                            child: FotoPrestador(url: foto.url, raio: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Avaliações',
                          style: estiloTexto(17, w: w800),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => mostrarAviso(
                          context,
                          'Todas as avaliações — em breve.',
                        ),
                        child: Text(
                          'Ver ${p.totalAvaliacoes}',
                          style: estiloTexto(13, w: w700, c: CoresApp.verde),
                        ),
                      ),
                    ],
                  ),
                ),
                VistaLista<AvaliacaoModelo>(
                  valor: ref.watch(avaliacoesPrestadorProvider(p.perfilId)),
                  aoRepetir: () =>
                      ref.invalidate(avaliacoesPrestadorProvider(p.perfilId)),
                  mensagemVazia: 'Ainda não tem avaliações.',
                  construir: (avaliacoes) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: comEspaco([
                      for (final a in avaliacoes) _CartaoAvaliacao(a),
                    ], 14),
                  ),
                ),
              ], 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estatistica(Widget valor, String rotulo) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          valor,
          Text(rotulo, style: estiloTexto(11.5, c: CoresApp.atenuado)),
        ],
      ),
    ),
  );

  /// A fotografia em grande, com a legenda.
  void _verFoto(BuildContext context, FotoPortfolioModelo foto) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: CoresApp.pagina,
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: FotoPrestador(url: foto.url, raio: 0),
              ),
              if (foto.legenda case final legenda? when legenda.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(legenda, style: estiloTexto(14, w: w700, h: 1.4)),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Fechar',
                    style: estiloTexto(14, w: w700, c: CoresApp.verde),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _cabecalho(String t) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(t, style: estiloTexto(17, w: w800)),
  );
}

class _CartaoAvaliacao extends StatelessWidget {
  const _CartaoAvaliacao(this.a);

  final AvaliacaoModelo a;

  @override
  Widget build(BuildContext context) {
    final estrelas = a.estrelas.clamp(0, 5);
    return Cartao(
      raio: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(autorAbreviado(a.autor), style: estiloTexto(13, w: w700)),
              Text(
                haQuantoTempo(a.criadoEm, DateTime.now()),
                style: estiloTexto(13, c: CoresApp.atenuado),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '★' * estrelas,
                  style: estiloTexto(13, c: CoresApp.estrela, ls: 2 / 13),
                ),
                TextSpan(
                  text: '★' * (5 - estrelas),
                  style: estiloTexto(13, c: CoresApp.tracejado, ls: 2 / 13),
                ),
              ],
            ),
          ),
          if (a.comentario case final c? when c.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c, style: estiloTexto(14, h: 1.45)),
          ],
        ],
      ),
    );
  }
}
