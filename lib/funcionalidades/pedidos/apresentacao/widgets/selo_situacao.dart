import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../controladores/pedidos_controlador.dart';

/// Selo colorido com a situação de um pedido.
class SeloSituacao extends StatelessWidget {
  const SeloSituacao(this.situacao, {super.key});

  final SituacaoPedido situacao;

  @override
  Widget build(BuildContext context) {
    final (fundo, frente) = switch (situacao) {
      SituacaoPedido.pendente => (CoresApp.ambarFundo, CoresApp.ambarFrente),
      SituacaoPedido.emCurso => (CoresApp.verdeClaro, CoresApp.verdeEscuro),
      SituacaoPedido.concluido => (CoresApp.areia, CoresApp.corpo),
      SituacaoPedido.rejeitado || SituacaoPedido.cancelado => (
        CoresApp.vermelhoFundo,
        CoresApp.vermelhoFrente,
      ),
    };
    return Selo(situacao.rotulo, fundo: fundo, frente: frente);
  }
}
