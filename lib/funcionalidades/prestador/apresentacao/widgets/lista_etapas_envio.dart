import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../controladores/cadastro_prestador_estado.dart';

/// Progresso do envio: uma linha por etapa, com o estado de cada uma.
class ListaEtapasEnvio extends StatelessWidget {
  const ListaEtapasEnvio({
    super.key,
    required this.etapas,
    required this.concluidas,
    required this.actual,
    required this.falhou,
  });

  final List<EtapaEnvio> etapas;
  final Set<EtapaEnvio> concluidas;
  final EtapaEnvio? actual;

  /// A etapa [actual] parou com erro.
  final bool falhou;

  @override
  Widget build(BuildContext context) {
    final feitas = etapas.where(concluidas.contains).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: feitas / etapas.length,
            minHeight: 6,
            color: falhou ? CoresApp.rejeitar : CoresApp.verde,
            backgroundColor: CoresApp.areia,
          ),
        ),
        const SizedBox(height: 16),
        Cartao(
          preenchimento: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < etapas.length; i++)
                _LinhaEtapa(
                  rotulo: etapas[i].rotulo,
                  situacao: concluidas.contains(etapas[i])
                      ? _Situacao.feita
                      : etapas[i] == actual
                      ? (falhou ? _Situacao.falhou : _Situacao.aCorrer)
                      : _Situacao.porFazer,
                  ultima: i == etapas.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Situacao { porFazer, aCorrer, feita, falhou }

class _LinhaEtapa extends StatelessWidget {
  const _LinhaEtapa({
    required this.rotulo,
    required this.situacao,
    required this.ultima,
  });

  static const _lado = 22.0;

  final String rotulo;
  final _Situacao situacao;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final indicador = switch (situacao) {
      _Situacao.aCorrer => const SizedBox.square(
        dimension: _lado,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: CoresApp.verde,
          ),
        ),
      ),
      _Situacao.feita => const PontoVerificado(tamanho: _lado),
      _Situacao.falhou => Container(
        width: _lado,
        height: _lado,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: CoresApp.rejeitar,
          shape: BoxShape.circle,
        ),
        child: Text(
          '!',
          style: estiloTexto(13, w: w800, c: Colors.white, h: 1),
        ),
      ),
      _Situacao.porFazer => Container(
        width: _lado,
        height: _lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CoresApp.tracejado, width: 1.5),
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: CoresApp.divisor)),
      ),
      child: Row(
        children: [
          indicador,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rotulo,
              style: estiloTexto(
                14,
                w: situacao == _Situacao.porFazer ? w500 : w700,
                c: switch (situacao) {
                  _Situacao.porFazer => CoresApp.atenuado,
                  _Situacao.falhou => CoresApp.rejeitar,
                  _ => CoresApp.tinta,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
