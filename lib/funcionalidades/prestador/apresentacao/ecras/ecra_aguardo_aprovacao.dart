import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/apresentacao/ecras/ecra_encaminhamento.dart';

/// Prestador com sessão cujo registo ainda não foi aprovado. A aprovação é
/// feita no painel do Supabase; a app só volta a verificar.
class EcraAguardoAprovacao extends ConsumerWidget {
  const EcraAguardoAprovacao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.read(sessaoControladorProvider);
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 40, 24, 20),
        espaco: 12,
        children: [
          Text(
            'Registo em análise',
            style: estiloTexto(26, w: w800, ls: -0.02),
          ),
          Text(
            'Estamos a confirmar os seus dados e documentos. Assim que o '
            'registo for aprovado, o painel de prestador fica disponível.',
            style: estiloTexto(15, c: CoresApp.atenuado, h: 1.5),
          ),
          const Spacer(),
          BotaoPrimario('Verificar de novo', aoTocar: sessao.recalcularDestino),
          BotaoContorno(
            'Terminar sessão',
            aoTocar: () async {
              final erro = await sessao.terminarSessao();
              if (!context.mounted) return;
              if (erro != null) return mostrarAviso(context, erro);
              reiniciarCom(context, const EcraEncaminhamento());
            },
          ),
        ],
      ),
    );
  }
}
