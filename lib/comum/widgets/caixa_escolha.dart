import 'package:flutter/material.dart';

import '../../nucleo/tema/tema_app.dart';
import 'componentes.dart';

/// Opção seleccionável com fundo verde claro quando activa.
class CaixaEscolha extends StatelessWidget {
  const CaixaEscolha({
    super.key,
    required this.rotulo,
    required this.seleccionado,
    required this.aoTocar,
    this.altura = 48,
  });

  final String rotulo;
  final bool seleccionado;
  final VoidCallback aoTocar;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Toque(
      aoTocar: aoTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: altura,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado ? CoresApp.verdeClaro : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? CoresApp.verde : CoresApp.borda,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Text(
          rotulo,
          style: estiloTexto(
            15,
            w: seleccionado ? w800 : w700,
            c: seleccionado ? CoresApp.verdeEscuro : CoresApp.tinta,
          ),
        ),
      ),
    );
  }
}
