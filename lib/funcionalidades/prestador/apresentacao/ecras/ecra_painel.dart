import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/dados/dados_exemplo.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../cliente/apresentacao/ecras/ecra_principal_cliente.dart';
import '../../../concursos/apresentacao/ecras/ecra_oportunidades.dart';
import '../../dados/modelos/painel_prestador_modelo.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import '../controladores/painel_controlador.dart';
import 'ecra_assinatura.dart';
import 'ecra_principal_prestador.dart';

/// 10 · Painel
///
/// Nome, foto, título ou categoria, zonas e estatísticas vêm de
/// `prestadores` + `perfis`; o pedido novo mais recente, de `pedidos`. Os
/// concursos, os ganhos e o plano continuam de exemplo até esses passos serem
/// ligados.
class EcraPainel extends ConsumerWidget {
  const EcraPainel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(painelProvider)
        .when(
          loading: () => const EcraBase(child: EstadoCarregar()),
          error: (erro, _) => EcraBase(
            child: EstadoErro(
              mensagem: mensagemDe(erro),
              aoRepetir: () => ref.invalidate(painelProvider),
            ),
          ),
          data: (painel) => painel == null
              ? const EcraBase(
                  child: EstadoVazio(
                    'Ainda não tem registo de prestador. Registe-se em Conta '
                    'para ter o seu painel.',
                  ),
                )
              : _conteudo(context, painel),
        );
  }

  Widget _conteudo(BuildContext context, PainelPrestadorModelo painel) {
    final topo = MediaQuery.paddingOf(context).top;
    final zonas = resumoZonas(painel.zonas);
    final descricao = [
      ?painel.descricao,
      if (zonas.isNotEmpty) zonas,
    ].join(' · ');
    return EcraBase(
      topoSeguro: false,
      barraEstadoClara: true,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: CoresApp.verdeEscuro,
            padding: EdgeInsets.fromLTRB(20, topo + 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Foto(url: painel.fotoUrl, nome: painel.nome),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bom dia,',
                            style: estiloTexto(
                              13,
                              c: CoresApp.sobreVerdeEscuroAtenuado,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  primeiroNome(painel.nome),
                                  overflow: TextOverflow.ellipsis,
                                  style: estiloTexto(
                                    22,
                                    w: w800,
                                    c: Colors.white,
                                  ),
                                ),
                              ),
                              if (painel.verificado) ...[
                                const SizedBox(width: 6),
                                const PontoVerificado(),
                              ],
                            ],
                          ),
                          if (descricao.isNotEmpty)
                            Text(
                              descricao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: estiloTexto(
                                12.5,
                                c: CoresApp.sobreVerdeEscuroAtenuado,
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => navegarPara(context, const EcraAssinatura()),
                      child: Selo(
                        'Premium',
                        fundo: Colors.white,
                        frente: CoresApp.verdeEscuro,
                        raio: 12,
                        preenchimento: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ganhos este mês',
                  style: estiloTexto(13, c: CoresApp.sobreVerdeEscuroAtenuado),
                ),
                const SizedBox(height: 2),
                Text(
                  '18 400 MT',
                  style: estiloTexto(34, w: w800, c: Colors.white, ls: -0.02),
                ),
                const SizedBox(height: 2),
                Text(
                  '+22% face a Agosto',
                  style: estiloTexto(13, c: CoresApp.sobreVerdeEscuroAtenuado),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GrelhaUniforme(
              colunas: 2,
              children: [
                for (final (v, l) in indicadoresDe(painel))
                  Cartao(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v, style: estiloTexto(22, w: w800)),
                        const SizedBox(height: 4),
                        Text(l, style: estiloTexto(12.5, c: CoresApp.atenuado)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: comEspaco([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        'Novos pedidos',
                        style: estiloTexto(17, w: w800),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => EcraPrincipalPrestador.irPara(
                        context,
                        EcraPrincipalPrestador.pedidos,
                      ),
                      child: Text(
                        'Ver todos',
                        style: estiloTexto(13, w: w700, c: CoresApp.verde),
                      ),
                    ),
                  ],
                ),
                const _ProximoPedido(),
                // Ponto de entrada para os concursos (telas 17–18); não existe no design do painel.
                Cartao(
                  aoTocar: () =>
                      navegarPara(context, const EcraOportunidades()),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Concursos abertos',
                              style: estiloTexto(15, w: w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DadosExemplo.concursos.length} na sua zona · responda com o seu valor',
                              style: estiloTexto(13, c: CoresApp.atenuado),
                            ),
                          ],
                        ),
                      ),
                      Text('›', style: estiloTexto(20, c: CoresApp.atenuado)),
                    ],
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        reiniciarCom(context, const EcraPrincipalCliente()),
                    child: Text(
                      'Mudar para cliente',
                      style: estiloTexto(13, w: w700, c: CoresApp.atenuado),
                    ),
                  ),
                ),
              ], 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de perfil; sem foto (ou se não carregar), a inicial do nome.
class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.nome});

  static const _lado = 48.0;

  final String? url;
  final String nome;

  @override
  Widget build(BuildContext context) {
    final inicial = Container(
      alignment: Alignment.center,
      color: Colors.white,
      child: Text(
        nome.isEmpty ? '?' : nome.characters.first.toUpperCase(),
        style: estiloTexto(18, w: w800, c: CoresApp.verdeEscuro),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: _lado,
        child: url == null
            ? inicial
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, _, _) => inicial,
              ),
      ),
    );
  }
}

/// O pedido pendente mais recente, com os três estados.
class _ProximoPedido extends ConsumerWidget {
  const _ProximoPedido();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void abrirPedidos() =>
        EcraPrincipalPrestador.irPara(context, EcraPrincipalPrestador.pedidos);
    final apoio = estiloTexto(13, c: CoresApp.atenuado);

    return ref
        .watch(pedidosPrestadorProvider)
        .when(
          loading: () =>
              Cartao(child: Text('A carregar pedidos…', style: apoio)),
          error: (erro, _) => Cartao(
            aoTocar: () => ref.invalidate(pedidosPrestadorProvider),
            child: MensagemErro(
              '${mensagemDe(erro)} Tocar para tentar de novo.',
            ),
          ),
          data: (pedidos) {
            final novo = pedidos
                .where((p) => situacaoDe(p) == SituacaoPedido.pendente)
                .firstOrNull;
            if (novo == null) {
              return Cartao(
                aoTocar: abrirPedidos,
                child: Text('Sem pedidos novos de momento.', style: apoio),
              );
            }
            return _CartaoNovo(novo, aoTocar: abrirPedidos);
          },
        );
  }
}

class _CartaoNovo extends StatelessWidget {
  const _CartaoNovo(this.pedido, {required this.aoTocar});

  final PedidoModelo pedido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    return Cartao(
      corBorda: CoresApp.verde,
      larguraBorda: 1.5,
      aoTocar: aoTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [haQuanto(pedido.criadoEm, agora), ?pedido.zona].join(' · '),
            style: estiloTexto(12.5, c: CoresApp.atenuado),
          ),
          const SizedBox(height: 6),
          Text(pedido.servico, style: estiloTexto(15, w: w800)),
          const SizedBox(height: 6),
          Text(
            quandoDe(pedido, agora),
            style: estiloTexto(13, c: CoresApp.atenuado),
          ),
        ],
      ),
    );
  }
}
