import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';

/// Campo de valor em MT, com número grande à esquerda e sufixo à direita.
class CampoDinheiro extends StatelessWidget {
  const CampoDinheiro({
    super.key,
    required this.controlador,
    this.altura = 60,
    this.tamanhoFonte = 26,
    this.sufixo = 'MT',
    this.destacado = false,
    this.aoMudar,
  });

  final TextEditingController controlador;
  final double altura;
  final double tamanhoFonte;
  final String sufixo;
  final bool destacado;
  final ValueChanged<String>? aoMudar;

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      controlador: controlador,
      altura: altura,
      raio: 14,
      margemH: 16,
      destacado: destacado,
      tipoTeclado: TextInputType.number,
      estilo: estiloTexto(tamanhoFonte, w: w800, ls: -0.01),
      aoMudar: (v) {
        final formatado = v.trim().isEmpty ? '' : formatarMt(lerMt(v));
        if (formatado != v) {
          controlador.value = TextEditingValue(
            text: formatado,
            selection: TextSelection.collapsed(offset: formatado.length),
          );
        }
        aoMudar?.call(formatado);
      },
      sufixo: Text(
        sufixo,
        style: estiloTexto(
          tamanhoFonte > 24 ? 15 : 14,
          w: w700,
          c: CoresApp.atenuado,
        ),
      ),
    );
  }
}
