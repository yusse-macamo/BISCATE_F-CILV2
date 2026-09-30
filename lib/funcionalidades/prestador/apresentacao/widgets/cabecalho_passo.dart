import 'package:flutter/material.dart';

import '../../../../nucleo/tema/tema_app.dart';

/// "PASSO 2 DE 3", barra de progresso, título e texto de apoio.
class CabecalhoPasso extends StatelessWidget {
  const CabecalhoPasso({
    super.key,
    required this.indice,
    required this.total,
    required this.titulo,
    required this.apoio,
  });

  final int indice;
  final int total;
  final String titulo;
  final String apoio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Passo ${indice + 1} de $total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASSO ${indice + 1} DE $total',
            style: estiloTexto(11.5, w: w800, c: CoresApp.atenuado, ls: 0.1),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (indice + 1) / total),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 6,
                color: CoresApp.verde,
                backgroundColor: CoresApp.areia,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(titulo, style: estiloTexto(26, w: w800, ls: -0.02)),
          const SizedBox(height: 6),
          Text(apoio, style: estiloTexto(14, c: CoresApp.atenuado, h: 1.45)),
        ],
      ),
    );
  }
}
