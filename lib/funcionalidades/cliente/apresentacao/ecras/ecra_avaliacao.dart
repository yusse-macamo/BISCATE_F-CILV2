import 'package:flutter/material.dart';

import '../../../../comum/widgets/caixa_escolha.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';

/// 09 · Avaliação
class EcraAvaliacao extends StatefulWidget {
  const EcraAvaliacao({
    super.key,
    this.nomePrestador = 'Carlos Mabunda',
    this.servico = 'Reparação eléctrica',
  });

  final String nomePrestador;
  final String servico;

  @override
  State<EcraAvaliacao> createState() => _EstadoEcraAvaliacao();
}

class _EstadoEcraAvaliacao extends State<EcraAvaliacao> {
  int _estrelas = 4;
  bool? _recomenda = true;

  static const _rotulos = [
    'Muito mau',
    'Mau',
    'Razoável',
    'Muito bom',
    'Excelente',
  ];

  @override
  Widget build(BuildContext context) {
    final primeiro = widget.nomePrestador.split(' ').first;
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 6, 24, 20),
        espaco: 20,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Text(
                'Agora não',
                style: estiloTexto(14, w: w700, c: CoresApp.atenuado),
              ),
            ),
          ),
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
                'Como foi o serviço do $primeiro?',
                textAlign: TextAlign.center,
                style: estiloTexto(22, w: w800, ls: -0.01),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.servico} · concluído',
                style: estiloTexto(14, c: CoresApp.atenuado),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: comEspaco(
                  [
                    for (var i = 1; i <= 5; i++)
                      Toque(
                        aoTocar: () => setState(() => _estrelas = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i <= _estrelas
                                ? CoresApp.ambarFundo
                                : CoresApp.areia,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '★',
                            style: estiloTexto(
                              26,
                              c: i <= _estrelas
                                  ? CoresApp.estrela
                                  : CoresApp.tracejado,
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
              Text(_rotulos[_estrelas - 1], style: estiloTexto(14, w: w700)),
            ],
          ),
          const ComRotulo(
            rotulo: 'Comentário',
            child: CampoTexto(
              altura: 96,
              multilinha: true,
              tamanhoFonte: 14,
              valorInicial: 'Chegou a horas e explicou tudo antes de começar.',
            ),
          ),
          ComRotulo(
            rotulo: 'Recomendaria a um amigo?',
            espaco: 8,
            child: GrelhaUniforme(
              colunas: 2,
              children: [
                CaixaEscolha(
                  rotulo: 'Sim',
                  seleccionado: _recomenda == true,
                  aoTocar: () => setState(() => _recomenda = true),
                ),
                CaixaEscolha(
                  rotulo: 'Não',
                  seleccionado: _recomenda == false,
                  aoTocar: () => setState(() => _recomenda = false),
                ),
              ],
            ),
          ),
          const Spacer(),
          BotaoPrimario(
            'Enviar avaliação',
            aoTocar: () {
              mostrarAviso(context, 'Obrigado! A sua avaliação foi enviada.');
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }
}
