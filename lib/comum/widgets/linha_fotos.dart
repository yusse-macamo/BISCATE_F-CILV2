import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../nucleo/tema/tema_app.dart';
import 'componentes.dart';

/// Miniaturas de fotos + botão tracejado "+".
class LinhaFotos extends StatelessWidget {
  const LinhaFotos({
    super.key,
    required this.contagem,
    required this.aoAdicionar,
    this.tamanho = 64,
    this.elementoFinal,
    this.miniaturas,
    this.aoTocarMiniatura,
  });

  /// Número de espaços riscados a mostrar quando não há [miniaturas].
  final int contagem;

  /// Fotografias escolhidas; quando existem, substituem os riscados.
  final List<Uint8List>? miniaturas;

  /// Tocar numa miniatura (ex.: para a remover).
  final ValueChanged<int>? aoTocarMiniatura;
  final VoidCallback aoAdicionar;
  final double tamanho;
  final Widget? elementoFinal;

  @override
  Widget build(BuildContext context) {
    // Wrap (e não um scroll horizontal) para funcionar dentro de FillScroll/IntrinsicHeight.
    return Wrap(
      spacing: elementoFinal == null ? 8 : 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (miniaturas case final fotos?)
          for (var i = 0; i < fotos.length; i++)
            Toque(
              aoTocar: aoTocarMiniatura == null
                  ? null
                  : () => aoTocarMiniatura!(i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  fotos[i],
                  width: tamanho,
                  height: tamanho,
                  fit: BoxFit.cover,
                  cacheWidth: (tamanho * 3).round(),
                  gaplessPlayback: true,
                ),
              ),
            )
        else
          for (var i = 0; i < contagem; i++)
            Riscado(largura: tamanho, altura: tamanho),
        CaixaTracejada(
          largura: tamanho,
          altura: tamanho,
          aoTocar: aoAdicionar,
          child: Text(
            '+',
            style: estiloTexto(tamanho > 56 ? 22 : 20, c: CoresApp.atenuado),
          ),
        ),
        ?elementoFinal,
      ],
    );
  }
}
