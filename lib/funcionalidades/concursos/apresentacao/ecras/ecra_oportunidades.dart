import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../dados/modelos/concurso_modelo.dart';
import '../controladores/concursos_controlador.dart';
import 'ecra_responder_concurso.dart';

/// 17 · Prestador · Oportunidades
///
/// Concursos abertos da categoria do prestador, nas zonas onde atende.
/// Enquanto não houver mapa, a proximidade é a zona e o filtro de distância
/// fica escondido.
class EcraOportunidades extends ConsumerStatefulWidget {
  const EcraOportunidades({super.key});

  @override
  ConsumerState<EcraOportunidades> createState() => _EstadoEcraOportunidades();
}

class _EstadoEcraOportunidades extends ConsumerState<EcraOportunidades> {
  String _ordenacao = 'Mais recentes';

  static const _ordens = [
    'Mais recentes',
    'Fecham primeiro',
    'Maior orçamento',
  ];

  List<ConcursoModelo> _ordenar(List<ConcursoModelo> concursos) {
    final lista = [...concursos];
    switch (_ordenacao) {
      case 'Fecham primeiro':
        lista.sort(
          (a, b) => (a.fechaEm ?? DateTime(9999)).compareTo(
            b.fechaEm ?? DateTime(9999),
          ),
        );
      case 'Maior orçamento':
        lista.sort((a, b) => (b.orcamento ?? 0).compareTo(a.orcamento ?? 0));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final oportunidades = ref.watch(oportunidadesProvider);
    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (Navigator.of(context).canPop()) ...[
                  const BotaoVoltar(),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Oportunidades',
                  style: estiloTexto(26, w: w800, ls: -0.02),
                ),
                const SizedBox(height: 2),
                Text(
                  'Concursos abertos do seu serviço, nas zonas onde atende',
                  style: estiloTexto(13.5, c: CoresApp.atenuado),
                ),
                const SizedBox(height: 12),
                Pilula(
                  '$_ordenacao ▾',
                  aoTocar: () async {
                    final v = await escolherOpcao(
                      context,
                      _ordens,
                      _ordenacao,
                      titulo: 'Ordenar por',
                    );
                    if (v != null) setState(() => _ordenacao = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: VistaLista<ConcursoModelo>(
              valor: oportunidades,
              aoRepetir: () => ref.invalidate(oportunidadesProvider),
              mensagemVazia:
                  'Não há concursos abertos nas suas zonas de momento.',
              construir: (lista) {
                final ordenada = _ordenar(lista);
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(oportunidadesProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: ordenada.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CartaoConcurso(ordenada[i]),
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

class _CartaoConcurso extends StatelessWidget {
  const _CartaoConcurso(this.t);

  final ConcursoModelo t;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      aoTocar: () =>
          navegarPara(context, EcraResponderConcurso(concursoId: t.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  [?t.zona, ?t.quando?.rotulo].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: estiloTexto(12.5, c: CoresApp.atenuado),
                ),
              ),
              Text(
                textoFecho(t.fechaEm, DateTime.now()),
                style: estiloTexto(12.5, w: w700, c: CoresApp.ambarFrente),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.titulo, style: estiloTexto(15.5, w: w800, h: 1.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Orçamento ',
                      style: estiloTexto(12, c: CoresApp.atenuado),
                    ),
                    TextSpan(
                      text: textoOrcamento(t.orcamento),
                      style: estiloTexto(17, w: w800),
                    ),
                  ],
                ),
              ),
              // As propostas dos outros não são visíveis ao prestador; só
              // se mostra se ele já respondeu.
              if (t.jaRespondido)
                Text(
                  'Já respondeu',
                  style: estiloTexto(12.5, w: w700, c: CoresApp.verde),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
