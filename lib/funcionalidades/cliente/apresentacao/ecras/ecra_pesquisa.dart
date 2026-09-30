import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../../dados/modelos/prestador_publico_modelo.dart';
import '../../dados/repositorios/procura_repositorio.dart';
import '../controladores/procura_controlador.dart';
import '../widgets/foto_prestador.dart';
import 'ecra_perfil_prestador.dart';

/// 05 · Pesquisa e filtros
///
/// Lê `prestadores` com `perfis` e `precos_prestador`. A visibilidade é da
/// RLS: aqui não se esconde ninguém. Ordena por reputação ou por serviços
/// feitos, nunca por preço. Sem mapa, a proximidade é a zona (`zona_id`); não
/// há filtro de distância.
class EcraPesquisa extends ConsumerStatefulWidget {
  const EcraPesquisa({super.key, this.consultaInicial = '', this.aoVoltar});

  final String consultaInicial;
  final VoidCallback? aoVoltar;

  @override
  ConsumerState<EcraPesquisa> createState() => _EstadoEcraPesquisa();
}

class _EstadoEcraPesquisa extends ConsumerState<EcraPesquisa> {
  late final _texto = TextEditingController(text: widget.consultaInicial);

  static const _ordens = {
    'Melhor avaliados': OrdemProcura.reputacao,
    'Mais serviços': OrdemProcura.servicosFeitos,
  };

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  ProcuraControlador get _controlador =>
      ref.read(procuraControladorProvider(widget.consultaInicial).notifier);

  /// Município e bairro vêm de `zonas`. Enquanto carregam, ou se falharem,
  /// a pílula diz isso em vez de mostrar opções inventadas.
  List<Widget> _filtrosZona(
    FiltroProcura filtro,
    AsyncValue<List<ZonaModelo>> zonas,
  ) => zonas.when(
    loading: () => const [Pilula('A carregar zonas…')],
    error: (erro, _) => [
      Pilula(
        'Zonas: tentar de novo',
        aoTocar: () {
          mostrarAviso(context, mensagemDe(erro));
          ref.invalidate(zonasProvider);
        },
      ),
    ],
    data: (lista) {
      if (lista.isEmpty) return const [];
      final doMunicipio = filtro.municipio == null
          ? lista
          : zonasDoMunicipio(lista, filtro.municipio);
      return [
        Pilula(
          '${filtro.municipio ?? 'Município'} ▾',
          seleccionado: filtro.municipio != null,
          aoTocar: () async {
            final v = await escolherOpcao(
              context,
              ['Todos', ...municipiosDe(lista)],
              filtro.municipio ?? 'Todos',
              titulo: 'Município',
            );
            if (v != null) {
              _controlador.escolherMunicipio(v == 'Todos' ? null : v);
            }
          },
        ),
        Pilula(
          '${filtro.zonaNome ?? 'Bairro'} ▾',
          seleccionado: filtro.zonaId != null,
          aoTocar: () async {
            final porNome = {for (final zona in doMunicipio) zona.nome: zona};
            final v = await escolherOpcao(
              context,
              ['Todos', ...porNome.keys],
              filtro.zonaNome ?? 'Todos',
              titulo: 'Bairro',
            );
            if (v != null) _controlador.escolherZona(porNome[v]);
          },
        ),
      ];
    },
  );

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(
      procuraControladorProvider(widget.consultaInicial),
    );
    final resultados = ref.watch(resultadosProcuraProvider(filtro));
    final rotuloOrdem = _ordens.entries
        .firstWhere((e) => e.value == filtro.ordem)
        .key;
    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: CoresApp.borda)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BotaoVoltar(aoTocar: widget.aoVoltar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CampoTexto(
                        controlador: _texto,
                        altura: 46,
                        destacado: true,
                        textoDica: 'Canalizador, electricista…',
                        estilo: estiloTexto(15, w: w600),
                        aoMudar: _controlador.definirTexto,
                        sufixo: GestureDetector(
                          onTap: () {
                            _texto.clear();
                            _controlador.limparTexto();
                          },
                          child: Text(
                            '✕',
                            style: estiloTexto(15, c: CoresApp.atenuado),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._filtrosZona(filtro, ref.watch(zonasProvider)),
                    Pilula(
                      'Até 1 000 MT',
                      seleccionado: filtro.ate1000,
                      aoTocar: _controlador.alternarAte1000,
                    ),
                    Pilula(
                      '4★ ou mais',
                      seleccionado: filtro.minimo4,
                      aoTocar: _controlador.alternarMinimo4,
                    ),
                    Pilula(
                      '✓ Verificado',
                      seleccionado: filtro.verificados,
                      aoTocar: _controlador.alternarVerificados,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: switch (resultados.valueOrNull?.length) {
                            null => 'A procurar…',
                            1 => '1 prestador',
                            final n => '$n prestadores',
                          },
                          style: estiloTexto(13, w: w700),
                        ),
                        TextSpan(
                          text: filtro.municipio == null
                              ? ''
                              : ' em ${filtro.zonaNome ?? filtro.municipio}',
                          style: estiloTexto(13, c: CoresApp.atenuado),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final v = await escolherOpcao(
                      context,
                      _ordens.keys.toList(),
                      rotuloOrdem,
                      titulo: 'Ordenar por',
                    );
                    if (v != null) _controlador.ordenar(_ordens[v]!);
                  },
                  child: Text(
                    '$rotuloOrdem ▾',
                    style: estiloTexto(13, w: w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: VistaLista<PrestadorPublicoModelo>(
              valor: resultados,
              aoRepetir: () =>
                  ref.invalidate(resultadosProcuraProvider(filtro)),
              mensagemVazia: 'Nenhum prestador corresponde a estes filtros.',
              construir: (lista) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => CartaoResultado(lista[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartaoResultado extends StatelessWidget {
  const CartaoResultado(this.p, {super.key});

  final PrestadorPublicoModelo p;

  @override
  Widget build(BuildContext context) {
    final avaliacao = textoAvaliacao(p);
    final desde = textoDesde(p);
    final linha = [?p.descricao, '${p.servicosFeitos} serviços'].join(' · ');
    return Cartao(
      preenchimento: const EdgeInsets.all(12),
      aoTocar: () =>
          navegarPara(context, EcraPerfilPrestador(prestadorId: p.perfilId)),
      child: Row(
        children: [
          FotoPrestador(url: p.fotoUrl, largura: 64, altura: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.nome,
                        style: estiloTexto(15, w: w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.verificado) ...[
                      const SizedBox(width: 6),
                      const PontoVerificado(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  linha,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloTexto(12.5, c: CoresApp.atenuado),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (avaliacao == null)
                      Text(
                        'Novo',
                        style: estiloTexto(13, w: w700, c: CoresApp.atenuado),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            spanEstrela(avaliacao),
                            TextSpan(
                              text: ' (${p.totalAvaliacoes})',
                              style: estiloTexto(
                                13,
                                w: w500,
                                c: CoresApp.atenuado,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (desde != null)
                      Text(desde, style: estiloTexto(13, w: w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
