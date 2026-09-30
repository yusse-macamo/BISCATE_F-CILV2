import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../cliente/apresentacao/ecras/ecra_principal_cliente.dart';
import '../../../prestador/apresentacao/ecras/ecra_aguardo_aprovacao.dart';
import '../../../prestador/apresentacao/ecras/ecra_principal_prestador.dart';
import '../controladores/sessao_controlador.dart';
import 'ecras_autenticacao.dart';

/// Raiz da app: mostra o ecrã certo para a sessão actual e muda sozinho
/// quando se entra ou sai.
///
/// Depois de entrar, registar ou terminar sessão, os ecrãs voltam aqui com
/// `reiniciarCom(context, const EcraEncaminhamento())`.
class EcraEncaminhamento extends ConsumerWidget {
  const EcraEncaminhamento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(destinoInicialProvider)
        .when(
          data: (destino) => switch (destino) {
            DestinoInicial.boasVindas => const EcraBoasVindas(),
            DestinoInicial.cliente => const EcraPrincipalCliente(),
            DestinoInicial.aguardoAprovacao => const EcraAguardoAprovacao(),
            DestinoInicial.prestador => const EcraPrincipalPrestador(),
          },
          loading: () => const EcraBase(child: EstadoCarregar()),
          error: (erro, _) => EcraBase(
            child: EstadoErro(
              mensagem: mensagemDe(erro),
              aoRepetir: ref.read(sessaoControladorProvider).recalcularDestino,
            ),
          ),
        );
  }
}
