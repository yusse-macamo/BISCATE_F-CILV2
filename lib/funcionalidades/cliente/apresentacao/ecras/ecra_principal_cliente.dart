import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import 'ecra_conta.dart';
import 'ecra_inicio.dart';
import 'ecra_meus_pedidos.dart';
import 'ecra_pesquisa.dart';

/// Navegação principal do cliente: Início · Pesquisar · Pedidos · Conta.
class EcraPrincipalCliente extends StatefulWidget {
  const EcraPrincipalCliente({super.key, this.separadorInicial = 0});

  final int separadorInicial;

  static const inicio = 0, pesquisa = 1, pedidos = 2, conta = 3;

  /// Muda de separador a partir de qualquer ecrã dentro do shell.
  static void irPara(BuildContext context, int separador, {String? consulta}) =>
      context
          .findAncestorStateOfType<_EstadoEcraPrincipalCliente>()
          ?._seleccionar(separador, consulta: consulta);

  @override
  State<EcraPrincipalCliente> createState() => _EstadoEcraPrincipalCliente();
}

class _EstadoEcraPrincipalCliente extends State<EcraPrincipalCliente> {
  late int _indice = widget.separadorInicial;
  String _consulta = '';
  int _versaoPesquisa = 0;

  void _seleccionar(int i, {String? consulta}) => setState(() {
    _indice = i;
    if (consulta != null) {
      _consulta = consulta;
      _versaoPesquisa++;
    }
  });

  @override
  Widget build(BuildContext context) {
    final paginas = [
      const EcraInicio(),
      EcraPesquisa(
        key: ValueKey(_versaoPesquisa),
        consultaInicial: _consulta,
        aoVoltar: () => _seleccionar(EcraPrincipalCliente.inicio),
      ),
      const EcraMeusPedidos(),
      const EcraConta(),
    ];
    return PopScope(
      canPop: _indice == EcraPrincipalCliente.inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _seleccionar(EcraPrincipalCliente.inicio);
      },
      child: Scaffold(
        body: IndexedStack(index: _indice, children: paginas),
        bottomNavigationBar: NavegacaoInferior(
          indice: _indice,
          aoTocar: _seleccionar,
          itens: const [
            ItemNavegacao('Início'),
            ItemNavegacao('Pesquisar', circulo: true),
            ItemNavegacao('Pedidos'),
            ItemNavegacao('Conta', circulo: true),
          ],
        ),
      ),
    );
  }
}
