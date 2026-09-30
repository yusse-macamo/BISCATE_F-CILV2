import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import '../../../trabalhos/apresentacao/controladores/trabalhos_controlador.dart';
import '../../../trabalhos/dados/modelos/trabalho_modelo.dart';

/// 14 · Gestão de pedidos
///
/// Aceitar chama `aceitar_pedido` (que cria o trabalho); rejeitar muda o
/// estado para `rejeitado`. O contacto do cliente só é legível depois de
/// aceitar: antes, a base não o devolve, e o cartão diz isso.
class EcraGestaoPedidos extends ConsumerStatefulWidget {
  const EcraGestaoPedidos({super.key});

  @override
  ConsumerState<EcraGestaoPedidos> createState() => _EstadoEcraGestaoPedidos();
}

enum _Separador { novos, aceites, concluidos }

class _EstadoEcraGestaoPedidos extends ConsumerState<EcraGestaoPedidos> {
  _Separador _separador = _Separador.novos;

  static List<PedidoModelo> _do(
    List<PedidoModelo> pedidos,
    _Separador separador,
  ) => [
    for (final p in pedidos)
      if (switch ((separador, situacaoDe(p))) {
        (_Separador.novos, SituacaoPedido.pendente) => true,
        (_Separador.aceites, SituacaoPedido.emCurso) => true,
        (_Separador.concluidos, SituacaoPedido.concluido) => true,
        _ => false,
      })
        p,
  ];

  Future<void> _aceitar(PedidoModelo pedido) async {
    final resposta = await _pedirValorAcordado(context);
    if (resposta == null || !mounted) return;
    final erro = await ref
        .read(respostaPedidoControladorProvider.notifier)
        .aceitar(pedido.id, valorAcordado: resposta.valor);
    if (!mounted) return;
    mostrarAviso(context, erro ?? 'Pedido aceite. O cliente foi notificado.');
  }

  Future<void> _rejeitar(PedidoModelo pedido) async {
    final confirmado = await escolherOpcao(
      context,
      const ['Rejeitar pedido', 'Cancelar'],
      '',
      titulo: 'Rejeitar "${pedido.servico}"?',
    );
    if (confirmado != 'Rejeitar pedido' || !mounted) return;
    final erro = await ref
        .read(respostaPedidoControladorProvider.notifier)
        .rejeitar(pedido.id);
    if (!mounted) return;
    mostrarAviso(context, erro ?? 'Pedido rejeitado.');
  }

  Future<void> _actualizar() async {
    ref
      ..invalidate(pedidosPrestadorProvider)
      ..invalidate(trabalhosConcursoPrestadorProvider);
    await Future.wait([
      ref.read(pedidosPrestadorProvider.future),
      ref.read(trabalhosConcursoPrestadorProvider.future),
    ]);
  }

  /// "Novos" são só pedidos pendentes (os concursos chegam pelas
  /// Oportunidades). "Aceites" e "Concluídos" juntam os trabalhos que vieram
  /// de pedidos com os que vieram de concursos adjudicados.
  Widget _lista(
    AsyncValue<List<PedidoModelo>> pedidos,
    Set<String> aResponder,
  ) {
    final concursos = _separador == _Separador.novos
        ? const AsyncData(<TrabalhoModelo>[])
        : ref.watch(trabalhosConcursoPrestadorProvider);
    final erro = pedidos.error ?? concursos.error;
    if (erro != null) {
      return EstadoErro(mensagem: mensagemDe(erro), aoRepetir: _actualizar);
    }
    if (!pedidos.hasValue || !concursos.hasValue) {
      return const EstadoCarregar();
    }

    final doPedido = _do(pedidos.requireValue, _separador);
    final deConcurso = [
      for (final t in concursos.requireValue)
        if (_separador == _Separador.aceites ? t.emCurso : t.concluido) t,
    ];
    final cartoes = <(DateTime?, Widget)>[
      for (final p in doPedido)
        (
          p.criadoEm,
          _CartaoPedidoRecebido(
            p,
            accoes: _separador == _Separador.novos,
            aResponder: aResponder.contains(p.id),
            aoRejeitar: () => _rejeitar(p),
            aoAceitar: () => _aceitar(p),
          ),
        ),
      for (final t in deConcurso) (t.criadoEm, _CartaoTrabalhoConcurso(t)),
    ]..sort((a, b) => (b.$1 ?? DateTime(0)).compareTo(a.$1 ?? DateTime(0)));

    if (cartoes.isEmpty) {
      return EstadoVazio(switch (_separador) {
        _Separador.novos => 'Sem pedidos novos de momento.',
        _Separador.aceites => 'Não tem trabalhos em curso.',
        _Separador.concluidos => 'Ainda não concluiu trabalhos.',
      });
    }
    return RefreshIndicator(
      onRefresh: _actualizar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: cartoes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => cartoes[i].$2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosPrestadorProvider);
    final aResponder = ref.watch(respostaPedidoControladorProvider);
    final novos = _do(pedidos.valueOrNull ?? const [], _Separador.novos);

    Pilula separador(String rotulo, _Separador valor) => Pilula(
      rotulo,
      margemH: 14,
      seleccionado: _separador == valor,
      corSeleccionada: CoresApp.tinta,
      aoTocar: () => setState(() => _separador = valor),
    );

    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedidos', style: estiloTexto(26, w: w800, ls: -0.02)),
                const SizedBox(height: 14),
                Row(
                  children: comEspaco(
                    [
                      separador(
                        pedidos.hasValue ? 'Novos (${novos.length})' : 'Novos',
                        _Separador.novos,
                      ),
                      separador('Aceites', _Separador.aceites),
                      separador('Concluídos', _Separador.concluidos),
                    ],
                    8,
                    eixo: Axis.horizontal,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _lista(pedidos, aResponder)),
        ],
      ),
    );
  }
}

/// Trabalho que veio de um concurso adjudicado. O cliente já escolheu esta
/// proposta, por isso o contacto é legível; concluir é do cliente.
class _CartaoTrabalhoConcurso extends StatelessWidget {
  const _CartaoTrabalhoConcurso(this.trabalho);

  final TrabalhoModelo trabalho;

  @override
  Widget build(BuildContext context) {
    final cliente = trabalho.cliente;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Selo(
                'Concurso',
                fundo: CoresApp.azulFundo,
                frente: CoresApp.azulFrente,
              ),
              if (trabalho.zona case final zona?)
                Text(zona, style: estiloTexto(12.5, c: CoresApp.atenuado)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trabalho.servico, style: estiloTexto(16, w: w800)),
              if (trabalho.descricao case final d? when d.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(d, style: estiloTexto(13.5, c: CoresApp.corpo, h: 1.45)),
              ],
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Etiqueta(textoValor(trabalho.valorAcordado), margemH: 10),
              if (trabalho.concluido) const Etiqueta('Concluído', margemH: 10),
            ],
          ),
          if (cliente == null)
            Text(
              'Contacto do cliente indisponível.',
              style: estiloTexto(12.5, c: CoresApp.atenuado, h: 1.4),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente.nome, style: estiloTexto(14, w: w700)),
                if (cliente.telefone case final telefone?)
                  Text(
                    '+258 $telefone',
                    style: estiloTexto(13.5, w: w600, c: CoresApp.verde),
                  ),
                if (trabalho.endereco case final endereco?)
                  Text(
                    endereco,
                    style: estiloTexto(12.5, c: CoresApp.atenuado, h: 1.4),
                  ),
              ],
            ),
        ], 10),
      ),
    );
  }
}

class _CartaoPedidoRecebido extends StatelessWidget {
  const _CartaoPedidoRecebido(
    this.pedido, {
    required this.accoes,
    required this.aResponder,
    required this.aoRejeitar,
    required this.aoAceitar,
  });

  final PedidoModelo pedido;
  final bool accoes;
  final bool aResponder;
  final VoidCallback aoRejeitar;
  final VoidCallback aoAceitar;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final quando = quandoDe(pedido, agora);
    final cliente = pedido.cliente;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                haQuanto(pedido.criadoEm, agora),
                style: estiloTexto(12.5, c: CoresApp.atenuado),
              ),
              if (pedido.zona case final zona?)
                Text(zona, style: estiloTexto(12.5, c: CoresApp.atenuado)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pedido.servico, style: estiloTexto(16, w: w800)),
              const SizedBox(height: 4),
              Text(
                pedido.descricao,
                style: estiloTexto(13.5, c: CoresApp.corpo, h: 1.45),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (quando.isNotEmpty) Etiqueta(quando, margemH: 10),
              if (pedido.numeroAnexos > 0)
                Etiqueta(
                  pedido.numeroAnexos == 1
                      ? '1 fotografia'
                      : '${pedido.numeroAnexos} fotografias',
                  margemH: 10,
                ),
              if (pedido.trabalho case final t?)
                Etiqueta(textoValor(t.valorAcordado), margemH: 10),
            ],
          ),
          // Sem trabalho, a RLS não devolve o perfil do cliente. É o estado
          // normal antes de aceitar, não um erro.
          if (cliente == null)
            Text(
              accoes
                  ? 'Nome e contacto do cliente ficam visíveis depois de aceitar.'
                  : 'Contacto do cliente indisponível.',
              style: estiloTexto(12.5, c: CoresApp.atenuado, h: 1.4),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente.nome, style: estiloTexto(14, w: w700)),
                if (cliente.telefone case final telefone?)
                  Text(
                    '+258 $telefone',
                    style: estiloTexto(13.5, w: w600, c: CoresApp.verde),
                  ),
                if (pedido.endereco case final endereco?)
                  Text(
                    endereco,
                    style: estiloTexto(12.5, c: CoresApp.atenuado, h: 1.4),
                  ),
              ],
            ),
          if (accoes)
            GrelhaUniforme(
              colunas: 2,
              espacoH: 8,
              flex: const [10, 14],
              children: [
                BotaoContorno(
                  '✕ Rejeitar',
                  altura: 46,
                  raio: 12,
                  tamanhoFonte: 14,
                  cor: CoresApp.rejeitar,
                  aoTocar: aResponder ? null : aoRejeitar,
                ),
                BotaoPrimario(
                  aResponder ? 'A responder…' : '✓ Aceitar',
                  altura: 46,
                  raio: 12,
                  tamanhoFonte: 14,
                  aoTocar: aResponder ? null : aoAceitar,
                ),
              ],
            ),
        ], 10),
      ),
    );
  }
}

/// Pergunta o valor combinado antes de aceitar. Em branco aceita sem valor
/// (combina-se depois). `null` se o prestador desistir.
Future<({int? valor})?> _pedirValorAcordado(BuildContext context) =>
    showModalBottomSheet<({int? valor})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CoresApp.pagina,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FolhaValorAcordado(),
    );

class _FolhaValorAcordado extends StatefulWidget {
  const _FolhaValorAcordado();

  @override
  State<_FolhaValorAcordado> createState() => _EstadoFolhaValorAcordado();
}

class _EstadoFolhaValorAcordado extends State<_FolhaValorAcordado> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aceitar pedido', style: estiloTexto(18, w: w800)),
            const SizedBox(height: 6),
            Text(
              'Se já combinou o valor com o cliente, indique-o. Pode deixar '
              'em branco e combinar depois.',
              style: estiloTexto(13.5, c: CoresApp.atenuado, h: 1.45),
            ),
            const SizedBox(height: 14),
            ComRotulo(
              rotulo: 'Valor combinado',
              dica: '(opcional)',
              child: CampoTexto(
                controlador: _texto,
                tipoTeclado: TextInputType.number,
                textoDica: 'Ex.: 1 500',
                sufixo: Text(' MT', style: estiloTexto(15, w: w800)),
              ),
            ),
            const SizedBox(height: 16),
            BotaoPrimario(
              'Aceitar',
              aoTocar: () {
                final valor = lerMt(_texto.text);
                Navigator.pop(context, (valor: valor > 0 ? valor : null));
              },
            ),
          ],
        ),
      ),
    );
  }
}
