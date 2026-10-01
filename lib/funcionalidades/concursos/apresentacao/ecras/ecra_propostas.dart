import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../cliente/apresentacao/ecras/ecra_perfil_prestador.dart';
import '../../../cliente/apresentacao/widgets/foto_prestador.dart';
import '../../dados/modelos/concurso_modelo.dart';
import '../controladores/concursos_controlador.dart';
import 'ecra_prestador_escolhido.dart';

/// 19 · Cliente · Escolher prestador
///
/// Lê as propostas do concurso. Escolher chama `adjudicar_concurso`, que
/// fecha as outras e cria o trabalho numa só transacção no servidor.
class EcraPropostas extends ConsumerStatefulWidget {
  const EcraPropostas({super.key, required this.concursoId});

  final String concursoId;

  @override
  ConsumerState<EcraPropostas> createState() => _EstadoEcraPropostas();
}

class _EstadoEcraPropostas extends ConsumerState<EcraPropostas> {
  String _ordenacao = 'Melhor avaliados';

  List<PropostaModelo> _ordenar(List<PropostaModelo> propostas) {
    final lista = [...propostas];
    if (_ordenacao == 'Melhor avaliados') {
      lista.sort(
        (a, b) => (b.avaliacaoMedia ?? 0).compareTo(a.avaliacaoMedia ?? 0),
      );
    } else {
      lista.sort((a, b) => a.valor.compareTo(b.valor));
    }
    return lista;
  }

  Future<void> _escolher(ConcursoModelo concurso, PropostaModelo p) async {
    final confirmado = await escolherOpcao(
      context,
      ['Escolher ${p.nome}', 'Cancelar'],
      '',
      titulo: 'Os outros prestadores são avisados de que o concurso fechou.',
    );
    if (confirmado != 'Escolher ${p.nome}' || !mounted) return;
    final erro = await ref
        .read(adjudicacaoControladorProvider.notifier)
        .escolher(concurso.id, p.id);
    if (!mounted) return;
    if (erro != null) return mostrarAviso(context, erro);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EcraPrestadorEscolhido(
          concursoId: concurso.id,
          nome: p.nome,
          servico: concurso.servico ?? concurso.titulo,
          preco: textoOrcamento(p.valor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final concurso = ref.watch(concursoProvider(widget.concursoId));
    final propostas = ref.watch(propostasProvider(widget.concursoId));
    final aEscolher = ref.watch(adjudicacaoControladorProvider);
    final c = concurso.valueOrNull;

    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: CoresApp.borda)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaTitulo(
                  titulo: c?.titulo ?? 'Propostas',
                  subtitulo: c == null
                      ? null
                      : [
                          'Orçamento ${textoOrcamento(c.orcamento)}',
                          if (c.estado == EstadoConcurso.aberto)
                            textoFecho(c.fechaEm, DateTime.now()).toLowerCase()
                          else
                            c.estado.rotulo.toLowerCase(),
                        ].join(' · '),
                  tamanhoTitulo: 16,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(switch (propostas.valueOrNull?.length) {
                        null => 'Propostas',
                        1 => '1 proposta',
                        final n => '$n propostas',
                      }, style: estiloTexto(13, w: w700)),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final v = await escolherOpcao(
                          context,
                          const ['Melhor avaliados', 'Mais baratos'],
                          _ordenacao,
                          titulo: 'Ordenar por',
                        );
                        if (v != null) setState(() => _ordenacao = v);
                      },
                      child: Text(
                        '$_ordenacao ▾',
                        style: estiloTexto(13, w: w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: concurso.hasError
                ? EstadoErro(
                    mensagem: mensagemDe(concurso.error!),
                    aoRepetir: () =>
                        ref.invalidate(concursoProvider(widget.concursoId)),
                  )
                : !concurso.isLoading && c == null
                ? const EstadoVazio('Este concurso já não está disponível.')
                : VistaLista<PropostaModelo>(
                    valor: propostas,
                    aoRepetir: () =>
                        ref.invalidate(propostasProvider(widget.concursoId)),
                    mensagemVazia:
                        'Ainda não há propostas. Os prestadores da zona foram '
                        'avisados; volte a ver daqui a pouco.',
                    construir: (lista) => RefreshIndicator(
                      onRefresh: () => ref.refresh(
                        propostasProvider(widget.concursoId).future,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = _ordenar(lista)[i];
                          return _CartaoProposta(
                            p,
                            podeEscolher:
                                c?.estado == EstadoConcurso.aberto &&
                                aEscolher == null,
                            aEscolher: aEscolher == p.id,
                            aoEscolher: c == null
                                ? null
                                : () => _escolher(c, p),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartaoProposta extends ConsumerWidget {
  const _CartaoProposta(
    this.p, {
    required this.podeEscolher,
    required this.aEscolher,
    required this.aoEscolher,
  });

  final PropostaModelo p;
  final bool podeEscolher;
  final bool aEscolher;
  final VoidCallback? aoEscolher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (fundo, frente) = p.tipo == TipoProposta.aceitaOrcamento
        ? (CoresApp.verdeClaro, CoresApp.verdeEscuro)
        : (CoresApp.ambarFundo, CoresApp.ambarFrente);
    final foto = urlFotoPerfil(
      ref.read(clienteSupabaseProvider),
      p.fotoCaminho,
    );
    return Cartao(
      preenchimento: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          Row(
            children: [
              FotoPrestador(url: foto, largura: 40, altura: 40, raio: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.nome,
                            style: estiloTexto(14.5, w: w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.verificado) ...[
                          const SizedBox(width: 6),
                          const PontoVerificado(tamanho: 15),
                        ],
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (p.avaliacaoMedia case final m?) ...[
                            TextSpan(
                              text: '★',
                              style: estiloTexto(12, c: CoresApp.estrela),
                            ),
                            TextSpan(
                              text: ' ${m.toStringAsFixed(1)} · ',
                              style: estiloTexto(12, c: CoresApp.atenuado),
                            ),
                          ],
                          TextSpan(
                            text: '${p.servicosFeitos} serviços',
                            style: estiloTexto(12, c: CoresApp.atenuado),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    textoOrcamento(p.valor),
                    style: estiloTexto(17, w: w800),
                  ),
                  Selo(
                    p.tipo.rotulo,
                    fundo: fundo,
                    frente: frente,
                    tamanhoFonte: 11,
                    raio: 8,
                    preenchimento: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (p.justificacao case final j? when j.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: CoresApp.areiaClara,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                j,
                style: estiloTexto(13, c: CoresApp.corpo, h: 1.45),
              ),
            ),
          if (p.estado == EstadoProposta.escolhida)
            Text(
              'Escolhida',
              style: estiloTexto(13, w: w700, c: CoresApp.verde),
            )
          else
            GrelhaUniforme(
              colunas: 2,
              espacoH: 8,
              flex: const [10, 14],
              children: [
                BotaoContorno(
                  'Ver perfil',
                  altura: 40,
                  raio: 11,
                  tamanhoFonte: 13.5,
                  aoTocar: () => navegarPara(
                    context,
                    EcraPerfilPrestador(prestadorId: p.prestadorId),
                  ),
                ),
                BotaoPrimario(
                  aEscolher ? 'A escolher…' : 'Escolher',
                  altura: 40,
                  raio: 11,
                  tamanhoFonte: 13.5,
                  aoTocar: podeEscolher ? aoEscolher : null,
                ),
              ],
            ),
        ], 9),
      ),
    );
  }
}
