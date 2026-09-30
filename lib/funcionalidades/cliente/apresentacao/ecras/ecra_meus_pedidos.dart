import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../../pedidos/apresentacao/widgets/selo_situacao.dart';
import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import '../../../trabalhos/apresentacao/controladores/trabalhos_controlador.dart';
import '../../../trabalhos/dados/modelos/trabalho_modelo.dart';
import 'ecra_avaliacao.dart';

/// 08 · Meus pedidos
///
/// Junta duas fontes: os pedidos que ainda não têm trabalho (pendentes,
/// rejeitados, cancelados) e os trabalhos do cliente, venham de um pedido
/// aceite ou de um concurso adjudicado. Um pedido aceite aparece uma só vez,
/// como trabalho. É aqui que o cliente conclui o trabalho e o avalia.
class EcraMeusPedidos extends ConsumerStatefulWidget {
  const EcraMeusPedidos({super.key});

  @override
  ConsumerState<EcraMeusPedidos> createState() => _EstadoEcraMeusPedidos();
}

sealed class _Item {
  DateTime? get data;
  bool get activo;
}

class _ItemPedido extends _Item {
  _ItemPedido(this.pedido);

  final PedidoModelo pedido;

  @override
  DateTime? get data => pedido.criadoEm;

  @override
  bool get activo => pedido.estado == EstadoPedido.pendente;
}

class _ItemTrabalho extends _Item {
  _ItemTrabalho(this.trabalho);

  final TrabalhoModelo trabalho;

  @override
  DateTime? get data => trabalho.criadoEm;

  @override
  bool get activo => trabalho.emCurso;
}

class _EstadoEcraMeusPedidos extends ConsumerState<EcraMeusPedidos> {
  int _separador = 0;

  Future<void> _actualizar() async {
    ref
      ..invalidate(pedidosClienteProvider)
      ..invalidate(trabalhosClienteProvider);
    await Future.wait([
      ref.read(pedidosClienteProvider.future),
      ref.read(trabalhosClienteProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosClienteProvider);
    final trabalhos = ref.watch(trabalhosClienteProvider);
    final pronto = pedidos.hasValue && trabalhos.hasValue;

    final itens = pronto
        ? [
            for (final p in pedidos.requireValue)
              // Os aceites estão nos trabalhos.
              if (p.estado != EstadoPedido.aceite) _ItemPedido(p),
            for (final t in trabalhos.requireValue) _ItemTrabalho(t),
          ]
        : <_Item>[];
    itens.sort(
      (a, b) => (b.data ?? DateTime(0)).compareTo(a.data ?? DateTime(0)),
    );
    final activos = itens.where((i) => i.activo).toList();
    final historico = itens.where((i) => !i.activo).toList();
    final erro = pedidos.error ?? trabalhos.error;

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
                    pronto ? 'Activos (${activos.length})' : 'Activos',
                    'Histórico',
                  ],
                  indice: _separador,
                  aoMudar: (i) => setState(() => _separador = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: erro != null
                ? EstadoErro(mensagem: mensagemDe(erro), aoRepetir: _actualizar)
                : !pronto
                ? const EstadoCarregar()
                : Builder(
                    builder: (context) {
                      final lista = _separador == 0 ? activos : historico;
                      if (lista.isEmpty) {
                        return EstadoVazio(
                          _separador == 0
                              ? 'Não tem pedidos em curso. Procure um '
                                    'prestador e faça o seu primeiro pedido.'
                              : 'Ainda não tem pedidos no histórico.',
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: _actualizar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => switch (lista[i]) {
                            _ItemPedido(:final pedido) => _CartaoPedido(pedido),
                            _ItemTrabalho(:final trabalho) => _CartaoTrabalho(
                              trabalho,
                            ),
                          },
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

/// Pedido ainda sem trabalho: pendente, rejeitado ou cancelado.
class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido(this.pedido);

  final PedidoModelo pedido;

  @override
  Widget build(BuildContext context) {
    final situacao = situacaoDe(pedido);
    return Cartao(
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
            pedido.prestadorNome ?? 'Prestador',
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
        ],
      ),
    );
  }
}

/// Trabalho (de um pedido aceite ou de um concurso). O cliente conclui-o e,
/// depois de concluído, avalia-o.
class _CartaoTrabalho extends ConsumerWidget {
  const _CartaoTrabalho(this.trabalho);

  final TrabalhoModelo trabalho;

  SituacaoPedido get _situacao => trabalho.concluido
      ? SituacaoPedido.concluido
      : trabalho.cancelado
      ? SituacaoPedido.cancelado
      : SituacaoPedido.emCurso;

  void _avaliar(BuildContext context) => navegarPara(
    context,
    EcraAvaliacao(
      trabalhoId: trabalho.id,
      prestadorId: trabalho.prestadorId,
      nomePrestador: trabalho.prestadorNome,
      servico: trabalho.servico,
    ),
  );

  Future<void> _concluir(BuildContext context, WidgetRef ref) async {
    const sim = 'Sim, está concluído';
    final quem = trabalho.prestadorNome ?? 'o prestador';
    final resposta = await escolherOpcao(
      context,
      const [sim, 'Ainda não'],
      '',
      titulo: 'O trabalho de $quem está concluído?',
    );
    if (resposta != sim || !context.mounted) return;
    final erro = await ref
        .read(conclusaoControladorProvider.notifier)
        .concluir(trabalho.id);
    if (!context.mounted) return;
    mostrarAviso(context, erro ?? 'Trabalho concluído. Já o pode avaliar.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aConcluir = ref
        .watch(conclusaoControladorProvider)
        .contains(trabalho.id);
    final porAvaliar = trabalho.concluido && !trabalho.avaliado;
    return Cartao(
      aoTocar: porAvaliar ? () => _avaliar(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SeloSituacao(_situacao),
              if (trabalho.origemConcurso)
                Text(
                  'Concurso',
                  style: estiloTexto(12.5, c: CoresApp.atenuado),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(trabalho.servico, style: estiloTexto(15, w: w800)),
          const SizedBox(height: 8),
          Text(
            [
              trabalho.prestadorNome ?? 'Prestador',
              textoValor(trabalho.valorAcordado),
            ].join(' · '),
            style: estiloTexto(13, c: CoresApp.atenuado),
          ),
          if (trabalho.emCurso) ...[
            const SizedBox(height: 10),
            BotaoContorno(
              aConcluir ? 'A concluir…' : 'Marcar como concluído',
              altura: 42,
              raio: 12,
              tamanhoFonte: 14,
              cor: CoresApp.verde,
              aoTocar: aConcluir ? null : () => _concluir(context, ref),
            ),
          ] else if (porAvaliar) ...[
            const SizedBox(height: 8),
            Text(
              'Avaliar o serviço ›',
              style: estiloTexto(13, w: w700, c: CoresApp.verde),
            ),
          ] else if (trabalho.concluido) ...[
            const SizedBox(height: 8),
            Text(
              'Avaliado ✓',
              style: estiloTexto(13, w: w700, c: CoresApp.atenuado),
            ),
          ],
        ],
      ),
    );
  }
}
