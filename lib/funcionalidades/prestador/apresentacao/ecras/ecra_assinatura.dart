import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../dados/repositorios/assinatura_repositorio.dart';
import '../controladores/assinatura_controlador.dart';

/// 15 · Assinatura
///
/// Só leitura: planos, a assinatura do próprio e o período gratuito
/// (`vw_estado_gratuito`). A confirmação de pagamento ainda não existe.
class EcraAssinatura extends ConsumerStatefulWidget {
  const EcraAssinatura({super.key});

  @override
  ConsumerState<EcraAssinatura> createState() => _EstadoEcraAssinatura();
}

class _EstadoEcraAssinatura extends ConsumerState<EcraAssinatura> {
  String? _seleccionado;

  @override
  Widget build(BuildContext context) {
    final situacao = ref.watch(situacaoAssinaturaProvider);
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: [
          const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
          Text(
            'Consiga mais clientes',
            style: estiloTexto(26, w: w800, ls: -0.02),
          ),
          ...situacao.when(
            loading: () => const [EstadoCarregar()],
            error: (erro, _) => [
              EstadoErro(
                mensagem: mensagemDe(erro),
                aoRepetir: () => ref.invalidate(situacaoAssinaturaProvider),
              ),
            ],
            data: _conteudo,
          ),
        ],
      ),
    );
  }

  List<Widget> _conteudo(SituacaoAssinatura s) {
    if (s.planos.isEmpty) {
      return [
        Text(resumoSituacao(s), style: estiloTexto(14, c: CoresApp.atenuado)),
        const EstadoVazio('Ainda não há planos disponíveis.'),
      ];
    }
    final seleccionado =
        s.planos.where((p) => p.id == _seleccionado).firstOrNull ??
        s.planos.where((p) => p.id == s.assinatura?.planoId).firstOrNull ??
        s.planos.first;
    return [
      Text(
        resumoSituacao(s),
        style: estiloTexto(14, c: CoresApp.atenuado, h: 1.45),
      ),
      for (final plano in s.planos)
        _CartaoPlano(
          plano,
          seleccionado: plano.id == seleccionado.id,
          actual:
              s.assinatura?.activa == true && s.assinatura?.planoId == plano.id,
          aoTocar: () => setState(() => _seleccionado = plano.id),
        ),
      const Spacer(),
      // TODO: ligar a confirmação de pagamento (M-Pesa, e-Mola). A app não
      // escreve em `assinaturas` nem em `pagamentos`; isso é do servidor.
      BotaoPrimario(
        'Escolher ${seleccionado.nome}',
        aoTocar: () => mostrarAviso(
          context,
          'O pagamento por M-Pesa e e-Mola ainda não está disponível na app.',
        ),
      ),
      Center(
        child: Text(
          'Pagamento via M-Pesa e e-Mola em breve',
          style: estiloTexto(12.5, c: CoresApp.atenuado),
        ),
      ),
    ];
  }
}

class _CartaoPlano extends StatelessWidget {
  const _CartaoPlano(
    this.plano, {
    required this.seleccionado,
    required this.actual,
    required this.aoTocar,
  });

  final PlanoModelo plano;
  final bool seleccionado;
  final bool actual;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      preenchimento: const EdgeInsets.all(16),
      corBorda: seleccionado ? CoresApp.verde : CoresApp.borda,
      larguraBorda: seleccionado ? 2 : 1,
      aoTocar: aoTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(plano.nome, style: estiloTexto(16, w: w800)),
              ),
              Text(
                textoPrecoPlano(plano.preco),
                style: estiloTexto(22, w: w800),
              ),
            ],
          ),
          if (actual) ...[
            const SizedBox(height: 4),
            Text(
              'O seu plano actual',
              style: estiloTexto(12.5, w: w700, c: CoresApp.verde),
            ),
          ],
          if (plano.descricao case final d? when d.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d, style: estiloTexto(13, c: CoresApp.corpo, h: 1.5)),
          ],
        ],
      ),
    );
  }
}
