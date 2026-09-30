import 'package:flutter/material.dart';

import '../../../../comum/dados/dados_exemplo.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import 'ecra_responder_concurso.dart';

/// 17 · Prestador · Oportunidades
class EcraOportunidades extends StatefulWidget {
  const EcraOportunidades({super.key});

  @override
  State<EcraOportunidades> createState() => _EstadoEcraOportunidades();
}

class _EstadoEcraOportunidades extends State<EcraOportunidades> {
  String _raio = 'Até 10 km';
  String _ordenacao = 'Mais recentes';

  static const _raios = ['Até 3 km', 'Até 5 km', 'Até 10 km', 'Até 20 km'];

  @override
  Widget build(BuildContext context) {
    final maxKm = int.parse(_raio.replaceAll(RegExp(r'[^0-9]'), ''));
    final lista = DadosExemplo.concursos
        .where((t) => lerMt(t.distancia) <= maxKm)
        .toList();
    if (_ordenacao == 'Maior orçamento')
      lista.sort((a, b) => lerMt(b.orcamento).compareTo(lerMt(a.orcamento)));
    if (_ordenacao == 'Mais próximos')
      lista.sort((a, b) => lerMt(a.distancia).compareTo(lerMt(b.distancia)));
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
                  'Concursos abertos na sua zona',
                  style: estiloTexto(13.5, c: CoresApp.atenuado),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pilula('Canalização', seleccionado: true, aoTocar: () {}),
                    Pilula(
                      '$_raio ▾',
                      aoTocar: () async {
                        final v = await escolherOpcao(
                          context,
                          _raios,
                          _raio,
                          titulo: 'Distância',
                        );
                        if (v != null) setState(() => _raio = v);
                      },
                    ),
                    Pilula(
                      '$_ordenacao ▾',
                      aoTocar: () async {
                        final v = await escolherOpcao(
                          context,
                          const [
                            'Mais recentes',
                            'Mais próximos',
                            'Maior orçamento',
                          ],
                          _ordenacao,
                          titulo: 'Ordenar por',
                        );
                        if (v != null) setState(() => _ordenacao = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CartaoConcurso(lista[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoConcurso extends StatelessWidget {
  const _CartaoConcurso(this.t);

  final Concurso t;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      aoTocar: () => navegarPara(context, EcraResponderConcurso(concurso: t)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t.area} · ${t.distancia}',
                style: estiloTexto(12.5, c: CoresApp.atenuado),
              ),
              Text(
                'Fecha em ${t.restante}',
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
                      text: t.orcamento,
                      style: estiloTexto(17, w: w800),
                    ),
                  ],
                ),
              ),
              Text(
                '${t.contagem} propostas',
                style: estiloTexto(12.5, c: CoresApp.atenuado),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
