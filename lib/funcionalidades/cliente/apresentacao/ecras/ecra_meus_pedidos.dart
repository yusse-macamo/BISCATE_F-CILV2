import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../../pedidos/apresentacao/widgets/selo_situacao.dart';
import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import 'ecra_avaliacao.dart';

/// 08 · Meus pedidos
class EcraMeusPedidos extends ConsumerStatefulWidget {
  const EcraMeusPedidos({super.key});

  @override
  ConsumerState<EcraMeusPedidos> createState() => _EstadoEcraMeusPedidos();
}

class _EstadoEcraMeusPedidos extends ConsumerState<EcraMeusPedidos> {
  int _separador = 0;

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosClienteProvider);
    final todos = pedidos.valueOrNull ?? const <PedidoModelo>[];
    final activos = todos.where((p) => situacaoDe(p).activa).toList();
    final historico = todos.where((p) => !situacaoDe(p).activa).toList();
    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Meus pedidos',
                  style: estiloTexto(26, w: w800, ls: -0.02),
                ),
                const SizedBox(height: 14),
                Segmentado(
                  altura: 38,
                  rotulos: [
                    pedidos.hasValue
                        ? 'Activos (${activos.length})'
                        : 'Activos',
                    'Histórico',
                  ],
                  indice: _separador,
                  aoMudar: (i) => setState(() => _separador = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidos.when(
              loading: () => const EstadoCarregar(),
              error: (erro, _) => EstadoErro(
                mensagem: mensagemDe(erro),
                aoRepetir: () => ref.invalidate(pedidosClienteProvider),
              ),
              data: (_) {
                final lista = _separador == 0 ? activos : historico;
                if (lista.isEmpty) {
                  return EstadoVazio(
                    _separador == 0
                        ? 'Não tem pedidos em curso. Procure um prestador e '
                              'faça o seu primeiro pedido.'
                        : 'Ainda não tem pedidos no histórico.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(pedidosClienteProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CartaoPedido(lista[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido(this.pedido);

  final PedidoModelo pedido;

  @override
  Widget build(BuildContext context) {
    final situacao = situacaoDe(pedido);
    final quem = pedido.prestadorNome ?? 'Prestador';
    return Cartao(
      aoTocar: situacao == SituacaoPedido.concluido
          ? () => navegarPara(
              context,
              EcraAvaliacao(nomePrestador: quem, servico: pedido.servico),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SeloSituacao(situacao),
              Text(
                quandoDe(pedido, DateTime.now()),
                style: estiloTexto(12.5, c: CoresApp.atenuado),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(pedido.servico, style: estiloTexto(15, w: w800)),
          const SizedBox(height: 8),
          Text(
            [
              quem,
              if (pedido.trabalho case final t?) textoValor(t.valorAcordado),
            ].join(' · '),
            style: estiloTexto(13, c: CoresApp.atenuado),
          ),
          if (situacao == SituacaoPedido.rejeitado &&
              (pedido.motivoRejeicao?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              pedido.motivoRejeicao!,
              style: estiloTexto(12.5, c: CoresApp.corpo, h: 1.4),
            ),
          ],
          if (situacao == SituacaoPedido.concluido) ...[
            const SizedBox(height: 8),
            Text(
              'Avaliar o serviço ›',
              style: estiloTexto(13, w: w700, c: CoresApp.verde),
            ),
          ],
        ],
      ),
    );
  }
}
