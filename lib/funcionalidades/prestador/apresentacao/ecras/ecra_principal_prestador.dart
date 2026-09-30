import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import 'ecra_editar_perfil.dart';
import 'ecra_gestao_pedidos.dart';
import 'ecra_painel.dart';
import 'ecra_precos.dart';

/// Navegação do prestador: Painel · Pedidos · Serviços · Perfil.
class EcraPrincipalPrestador extends StatefulWidget {
  const EcraPrincipalPrestador({super.key, this.separadorInicial = 0});

  final int separadorInicial;

  static const painel = 0, pedidos = 1, servicos = 2, perfil = 3;

  static void irPara(BuildContext context, int separador) => context
      .findAncestorStateOfType<_EstadoEcraPrincipalPrestador>()
      ?._seleccionar(separador);

  @override
  State<EcraPrincipalPrestador> createState() =>
      _EstadoEcraPrincipalPrestador();
}

class _EstadoEcraPrincipalPrestador extends State<EcraPrincipalPrestador> {
  late int _indice = widget.separadorInicial;

  void _seleccionar(int i) => setState(() => _indice = i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _indice == EcraPrincipalPrestador.painel,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _seleccionar(EcraPrincipalPrestador.painel);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indice,
          children: [
            const EcraPainel(),
            const EcraGestaoPedidos(),
            EcraPrecos(
              aoVoltar: () => _seleccionar(EcraPrincipalPrestador.painel),
            ),
            EcraEditarPerfil(
              aoVoltar: () => _seleccionar(EcraPrincipalPrestador.painel),
            ),
          ],
        ),
        bottomNavigationBar: NavegacaoInferior(
          indice: _indice,
          aoTocar: _seleccionar,
          itens: const [
            ItemNavegacao('Painel'),
            ItemNavegacao('Pedidos'),
            ItemNavegacao('Serviços'),
            ItemNavegacao('Perfil', circulo: true),
          ],
        ),
      ),
    );
  }
}
