import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../comum/widgets/linha_fotos.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../../pedidos/apresentacao/controladores/solicitacao_controlador.dart';
import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import '../controladores/perfil_prestador_controlador.dart';
import 'ecra_principal_cliente.dart';

/// 07 · Solicitação
///
/// Insere em `pedidos` e envia as fotografias para o Storage (`anexos`).
/// O serviço tem de ser do catálogo; a data, o período e o bairro vão com os
/// valores que a base aceita.
class EcraSolicitacao extends ConsumerStatefulWidget {
  const EcraSolicitacao({super.key, this.prestadorId, this.nomePrestador});

  /// `perfil_id` do prestador. Sem ele não há a quem pedir.
  final String? prestadorId;
  final String? nomePrestador;

  @override
  ConsumerState<EcraSolicitacao> createState() => _EstadoEcraSolicitacao();
}

class _EstadoEcraSolicitacao extends ConsumerState<EcraSolicitacao> {
  final _descricao = TextEditingController();
  final _endereco = TextEditingController();

  @override
  void dispose() {
    _descricao.dispose();
    _endereco.dispose();
    super.dispose();
  }

  static void _ignorar(String _) {}

  @override
  Widget build(BuildContext context) {
    final prestadorId = widget.prestadorId;
    final titulo = LinhaTitulo(
      titulo: 'Solicitar serviço',
      subtitulo: widget.nomePrestador == null
          ? null
          : 'a ${widget.nomePrestador}',
    );
    if (prestadorId == null) {
      return EcraBase(
        child: ScrollPreenchido(
          preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          children: [
            titulo,
            const EstadoVazio(
              'Escolha um prestador para lhe pedir um serviço.',
            ),
          ],
        ),
      );
    }

    final provider = solicitacaoControladorProvider(prestadorId);
    final controlador = ref.read(provider.notifier);
    final estado = ref.watch(provider);
    ref.listen(provider.select((e) => e.enviado), (_, enviado) {
      if (!enviado) return;
      mostrarAviso(
        context,
        'Pedido enviado${widget.nomePrestador == null ? '' : ' a ${widget.nomePrestador}'}.',
      );
      reiniciarCom(
        context,
        const EcraPrincipalCliente(
          separadorInicial: EcraPrincipalCliente.pedidos,
        ),
      );
    });

    final hoje = DateTime.now();
    final datas = datasDisponiveis(hoje);
    final fechado = estado.pedidoGravado || estado.aEnviar;

    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: [
          titulo,
          ComRotulo(
            rotulo: 'Serviço',
            erro: estado.erros['servico'],
            child: _servico(prestadorId, estado, controlador, fechado),
          ),
          ComRotulo(
            rotulo: 'Descreva o problema',
            erro: estado.erros['descricao'],
            child: CampoTexto(
              controlador: _descricao,
              altura: 88,
              multilinha: true,
              tamanhoFonte: 14,
              textoDica: 'Ex.: As tomadas da cozinha deixaram de funcionar.',
              aoMudar: (_) => controlador.limparErro('descricao'),
            ),
          ),
          GrelhaUniforme(
            colunas: 2,
            children: [
              ComRotulo(
                rotulo: 'Data',
                child: CaixaSeleccao(
                  mostrarSeta: false,
                  titulo: 'Data',
                  activa: !fechado,
                  valor: rotuloData(estado.data, hoje),
                  opcoes: [for (final d in datas) rotuloData(d, hoje)],
                  aoMudar: (v) => controlador.escolherData(
                    datas.firstWhere((d) => rotuloData(d, hoje) == v),
                  ),
                ),
              ),
              ComRotulo(
                rotulo: 'Período',
                child: CaixaSeleccao(
                  mostrarSeta: false,
                  titulo: 'Período',
                  activa: !fechado,
                  valor: estado.periodo.rotulo,
                  opcoes: [for (final p in PeriodoDia.values) p.rotulo],
                  aoMudar: (v) => controlador.escolherPeriodo(
                    PeriodoDia.values.firstWhere((p) => p.rotulo == v),
                  ),
                ),
              ),
            ],
          ),
          ComRotulo(
            rotulo: 'Bairro',
            erro: estado.erros['zona'],
            child: VistaLista<ZonaModelo>(
              valor: ref.watch(zonasProvider),
              aoRepetir: () => ref.invalidate(zonasProvider),
              mensagemVazia: 'Ainda não há bairros disponíveis.',
              aCarregar: const CaixaSeleccao(
                valor: 'A carregar…',
                opcoes: [],
                aoMudar: _ignorar,
                activa: false,
              ),
              construir: (zonas) {
                String rotulo(ZonaModelo z) => '${z.nome}, ${z.municipio}';
                final escolhida = zonas
                    .where((z) => z.id == estado.zonaId)
                    .firstOrNull;
                return CaixaSeleccao(
                  titulo: 'Bairro',
                  activa: !fechado,
                  valor: escolhida == null ? 'Escolher' : rotulo(escolhida),
                  opcoes: [for (final z in zonas) rotulo(z)],
                  aoMudar: (v) => controlador.escolherZona(
                    zonas.firstWhere((z) => rotulo(z) == v).id,
                  ),
                );
              },
            ),
          ),
          ComRotulo(
            rotulo: 'Endereço',
            erro: estado.erros['endereco'],
            child: CampoTexto(
              controlador: _endereco,
              textoDica: 'Rua, número e uma referência',
              aoMudar: (_) => controlador.limparErro('endereco'),
            ),
          ),
          ComRotulo(
            rotulo: 'Fotografias',
            dica: '(opcional · toque para remover)',
            erro: estado.erros['fotos'],
            child: LinhaFotos(
              contagem: 0,
              tamanho: 64,
              miniaturas: [for (final f in estado.fotos) f.bytes],
              aoTocarMiniatura: fechado ? null : controlador.removerFoto,
              aoAdicionar: fechado ? () {} : () => _escolherFoto(controlador),
            ),
          ),
          if (estado.erroEnvio != null) MensagemErro(estado.erroEnvio!),
          const Spacer(),
          if (estado.pedidoGravado &&
              estado.erroEnvio != null &&
              !estado.aEnviar)
            BotaoContorno(
              'Continuar sem as fotografias',
              aoTocar: controlador.terminarSemFotografias,
            ),
          BotaoPrimario(
            estado.aEnviar
                ? (estado.etapa ?? 'A enviar…')
                : estado.pedidoGravado
                ? 'Tentar enviar as fotografias'
                : 'Enviar pedido',
            aoTocar: estado.aEnviar
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    controlador.enviar(
                      descricao: _descricao.text,
                      endereco: _endereco.text,
                    );
                  },
          ),
        ],
      ),
    );
  }

  /// Serviços do prestador com os três estados do perfil dele.
  Widget _servico(
    String prestadorId,
    EstadoSolicitacao estado,
    SolicitacaoControlador controlador,
    bool fechado,
  ) {
    const aCarregar = CaixaSeleccao(
      valor: 'A carregar…',
      opcoes: [],
      aoMudar: _ignorar,
      activa: false,
    );
    final catalogo = ref.watch(servicosProvider);
    return ref
        .watch(perfilPrestadorProvider(prestadorId))
        .when(
          loading: () => aCarregar,
          error: (erro, _) => EstadoErro(
            mensagem: mensagemDe(erro),
            aoRepetir: () =>
                ref.invalidate(perfilPrestadorProvider(prestadorId)),
          ),
          data: (prestador) {
            if (prestador == null) {
              return const EstadoVazio(
                'Este prestador não está disponível de momento.',
              );
            }
            if (catalogo.isLoading) return aCarregar;
            final opcoes = opcoesServico(
              prestador,
              catalogo.valueOrNull ?? const [],
            );
            if (opcoes.isEmpty) {
              return const EstadoVazio(
                'Este prestador ainda não indicou os serviços que faz.',
              );
            }
            final escolhida = opcoes
                .where((o) => o.$1 == estado.servicoId)
                .firstOrNull;
            return CaixaSeleccao(
              titulo: 'Serviço',
              activa: !fechado,
              valor: escolhida?.$2 ?? 'Escolher',
              opcoes: [for (final o in opcoes) o.$2],
              aoMudar: (v) => controlador.escolherServico(
                opcoes.firstWhere((o) => o.$2 == v).$1,
              ),
            );
          },
        );
  }

  Future<void> _escolherFoto(SolicitacaoControlador controlador) async {
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: 'Fotografia',
    );
    if (opcao == null) return;
    await controlador.adicionarFoto(
      opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria,
    );
  }
}
