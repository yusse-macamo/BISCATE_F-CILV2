import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/caixa_escolha.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../trabalhos/apresentacao/controladores/trabalhos_controlador.dart';

/// 09 · Avaliação
///
/// Insere em `avaliacoes` (trabalho_id, estrelas, comentario, recomenda). A
/// base só aceita se o trabalho estiver concluído e for de quem avalia; a
/// média do prestador actualiza-se por gatilho e a app só relê o perfil.
class EcraAvaliacao extends ConsumerStatefulWidget {
  const EcraAvaliacao({
    super.key,
    this.trabalhoId,
    this.prestadorId,
    this.nomePrestador,
    this.servico,
  });

  /// Sem trabalho não há o que avaliar (ex.: aberto do catálogo de telas).
  final String? trabalhoId;
  final String? prestadorId;
  final String? nomePrestador;
  final String? servico;

  @override
  ConsumerState<EcraAvaliacao> createState() => _EstadoEcraAvaliacao();
}

class _EstadoEcraAvaliacao extends ConsumerState<EcraAvaliacao> {
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trabalhoId = widget.trabalhoId;
    final prestadorId = widget.prestadorId;
    final agoraNao = Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Text(
          'Agora não',
          style: estiloTexto(14, w: w700, c: CoresApp.atenuado),
        ),
      ),
    );
    if (trabalhoId == null || prestadorId == null) {
      return EcraBase(
        child: ScrollPreenchido(
          preenchimento: const EdgeInsets.fromLTRB(24, 6, 24, 20),
          children: [
            agoraNao,
            const EstadoVazio(
              'Só pode avaliar um trabalho concluído. Encontra-os em Meus '
              'pedidos.',
            ),
          ],
        ),
      );
    }

    final provider = avaliacaoControladorProvider(trabalhoId);
    final estado = ref.watch(provider);
    final c = ref.read(provider.notifier);
    ref.listen(provider.select((e) => e.enviada), (_, enviada) {
      if (!enviada) return;
      mostrarAviso(context, 'Obrigado! A sua avaliação foi enviada.');
      Navigator.of(context).maybePop();
    });
    final nome = widget.nomePrestador?.trim() ?? '';
    final primeiro = nome.isEmpty ? null : nome.split(RegExp(r'\s+')).first;

    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 6, 24, 20),
        espaco: 20,
        children: [
          agoraNao,
          Column(
            children: [
              const Riscado(
                largura: 76,
                altura: 76,
                raio: 22,
                a: CoresApp.avatarA,
                b: CoresApp.avatarB,
              ),
              const SizedBox(height: 10),
              Text(
                primeiro == null
                    ? 'Como foi o serviço?'
                    : 'Como foi o serviço do $primeiro?',
                textAlign: TextAlign.center,
                style: estiloTexto(22, w: w800, ls: -0.01),
              ),
              if (widget.servico case final s?) ...[
                const SizedBox(height: 10),
                Text(
                  '$s · concluído',
                  style: estiloTexto(14, c: CoresApp.atenuado),
                ),
              ],
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: comEspaco(
                  [
                    for (var i = 1; i <= 5; i++)
                      Semantics(
                        button: true,
                        selected: i <= estado.estrelas,
                        label: '$i estrela${i == 1 ? '' : 's'}',
                        child: Toque(
                          aoTocar: () => c.escolherEstrelas(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i <= estado.estrelas
                                  ? CoresApp.ambarFundo
                                  : CoresApp.areia,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '★',
                              style: estiloTexto(
                                26,
                                c: i <= estado.estrelas
                                    ? CoresApp.estrela
                                    : CoresApp.tracejado,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  8,
                  eixo: Axis.horizontal,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                estado.estrelas == 0
                    ? 'Toque nas estrelas'
                    : AvaliacaoControlador.rotulos[estado.estrelas - 1],
                style: estiloTexto(
                  14,
                  w: w700,
                  c: estado.estrelas == 0 ? CoresApp.atenuado : null,
                ),
              ),
              if (estado.erros['estrelas'] case final e?) ...[
                const SizedBox(height: 6),
                MensagemErro(e),
              ],
            ],
          ),
          ComRotulo(
            rotulo: 'Comentário',
            dica: '(opcional)',
            erro: estado.erros['comentario'],
            child: CampoTexto(
              controlador: _comentario,
              altura: 96,
              multilinha: true,
              tamanhoFonte: 14,
              textoDica:
                  'Ex.: Chegou a horas e explicou tudo antes de começar.',
            ),
          ),
          ComRotulo(
            rotulo: 'Recomendaria a um amigo?',
            espaco: 8,
            erro: estado.erros['recomenda'],
            child: GrelhaUniforme(
              colunas: 2,
              children: [
                CaixaEscolha(
                  rotulo: 'Sim',
                  seleccionado: estado.recomenda == true,
                  aoTocar: () => c.escolherRecomenda(true),
                ),
                CaixaEscolha(
                  rotulo: 'Não',
                  seleccionado: estado.recomenda == false,
                  aoTocar: () => c.escolherRecomenda(false),
                ),
              ],
            ),
          ),
          if (estado.erroEnvio != null) MensagemErro(estado.erroEnvio!),
          const Spacer(),
          BotaoPrimario(
            estado.aEnviar ? 'A enviar…' : 'Enviar avaliação',
            aoTocar: estado.aEnviar
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    c.enviar(
                      prestadorId: prestadorId,
                      comentario: _comentario.text,
                    );
                  },
          ),
        ],
      ),
    );
  }
}
