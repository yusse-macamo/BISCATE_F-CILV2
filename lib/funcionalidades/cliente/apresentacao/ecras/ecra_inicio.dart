import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/categoria_modelo.dart';
import '../../dados/modelos/prestador_publico_modelo.dart';
import '../controladores/perfil_cliente_controlador.dart';
import '../controladores/procura_controlador.dart';
import '../widgets/foto_prestador.dart';
import 'ecra_perfil_prestador.dart';
import 'ecra_principal_cliente.dart';

/// 04 · Início
class EcraInicio extends ConsumerWidget {
  const EcraInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topo = MediaQuery.paddingOf(context).top;
    final categorias = ref.watch(categoriasProvider);
    // Cabeçalho: enquanto o perfil carrega (ou se falhar), só "Olá", sem
    // inventar nome nem zona. O conteúdo principal tem os seus três estados.
    final perfil = ref.watch(perfilClienteProvider).valueOrNull;
    final sugestoes = sugestoesDePesquisa(categorias.valueOrNull ?? const []);
    return EcraBase(
      topoSeguro: false,
      barraEstadoClara: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: CoresApp.verde,
            padding: EdgeInsets.fromLTRB(20, topo + 10, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (perfil != null &&
                              perfil.localizacao.isNotEmpty) ...[
                            Text(
                              perfil.localizacao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: estiloTexto(
                                13,
                                w: w600,
                                c: CoresApp.sobreVerdeAtenuado,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            perfil == null || perfil.nome.trim().isEmpty
                                ? 'Olá'
                                : 'Olá, ${perfil.primeiroNome}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: estiloTexto(22, w: w800, c: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => EcraPrincipalCliente.irPara(
                        context,
                        EcraPrincipalCliente.conta,
                      ),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          perfil?.inicial ?? '',
                          style: estiloTexto(16, w: w800, c: CoresApp.verde),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Toque(
                  raio: 14,
                  aoTocar: () => EcraPrincipalCliente.irPara(
                    context,
                    EcraPrincipalCliente.pesquisa,
                    consulta: '',
                  ),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text('⌕', style: estiloTexto(18, c: CoresApp.tinta)),
                        const SizedBox(width: 10),
                        Text(
                          'Canalizador, electricista…',
                          style: estiloTexto(15, c: CoresApp.atenuado),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sugestoes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: comEspaco(
                        [
                          for (final s in sugestoes)
                            Toque(
                              raio: 16,
                              aoTocar: () => EcraPrincipalCliente.irPara(
                                context,
                                EcraPrincipalCliente.pesquisa,
                                consulta: s,
                              ),
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  s,
                                  style: estiloTexto(
                                    13,
                                    w: w600,
                                    c: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        8,
                        eixo: Axis.horizontal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              children: comEspaco([
                _cabecalhoSeccao(
                  'Categorias',
                  'Ver todas',
                  () => EcraPrincipalCliente.irPara(
                    context,
                    EcraPrincipalCliente.pesquisa,
                    consulta: '',
                  ),
                ),
                VistaLista<CategoriaModelo>(
                  valor: categorias,
                  aoRepetir: () => ref.invalidate(categoriasProvider),
                  mensagemVazia: 'Ainda não há categorias disponíveis.',
                  construir: (lista) => GrelhaUniforme(
                    colunas: 4,
                    espacoH: 8,
                    espacoV: 12,
                    children: [for (final c in lista) _CelulaCategoria(c)],
                  ),
                ),
                Text(
                  'Em destaque perto de si',
                  style: estiloTexto(17, w: w800),
                ),
                VistaLista<PrestadorPublicoModelo>(
                  valor: ref.watch(destaquesProvider),
                  aoRepetir: () => ref.invalidate(destaquesProvider),
                  mensagemVazia:
                      'Ainda não há prestadores em destaque na sua zona.',
                  construir: (destaques) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: comEspaco(
                        [for (final p in destaques) _CartaoDestaque(p)],
                        12,
                        eixo: Axis.horizontal,
                      ),
                    ),
                  ),
                ),
              ], 16),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _cabecalhoSeccao(String titulo, String accao, VoidCallback aoTocar) =>
    Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(titulo, style: estiloTexto(17, w: w800)),
        ),
        GestureDetector(
          onTap: aoTocar,
          child: Text(
            accao,
            style: estiloTexto(13, w: w700, c: CoresApp.verde),
          ),
        ),
      ],
    );

class _CelulaCategoria extends StatelessWidget {
  const _CelulaCategoria(this.c);

  final CategoriaModelo c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => EcraPrincipalCliente.irPara(
        context,
        EcraPrincipalCliente.pesquisa,
        consulta: c.nome,
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CoresApp.verdeClaro,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              c.abreviatura,
              style: estiloTexto(15, w: w800, c: CoresApp.verde),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c.nome,
            style: estiloTexto(11.5, w: w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

class _CartaoDestaque extends StatelessWidget {
  const _CartaoDestaque(this.p);

  final PrestadorPublicoModelo p;

  @override
  Widget build(BuildContext context) {
    final avaliacao = textoAvaliacao(p);
    final desde = textoDesde(p);
    final linha = [
      ?p.descricao,
      if (p.zonas.isNotEmpty) p.zonas.first,
    ].join(' · ');
    return SizedBox(
      width: 204,
      child: Cartao(
        raio: 18,
        preenchimento: EdgeInsets.zero,
        aoTocar: () =>
            navegarPara(context, EcraPerfilPrestador(prestadorId: p.perfilId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FotoPrestador(url: p.fotoUrl, raio: 0),
                  if (p.verificado)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Selo(
                        '✓ Verificado',
                        fundo: CoresApp.verde,
                        frente: Colors.white,
                        tamanhoFonte: 11,
                        preenchimento: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    p.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: estiloTexto(15, w: w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    linha,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: estiloTexto(12.5, c: CoresApp.atenuado),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (avaliacao == null)
                        Text(
                          'Novo',
                          style: estiloTexto(13, w: w700, c: CoresApp.atenuado),
                        )
                      else
                        Text.rich(spanEstrela(avaliacao)),
                      if (desde != null)
                        Flexible(
                          child: Text(
                            desde,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: estiloTexto(13, w: w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
