import 'package:flutter/material.dart';

import '../../../../comum/dados/dados_exemplo.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../widgets/campo_dinheiro.dart';

/// 18 · Prestador · Responder a um concurso
class EcraResponderConcurso extends StatefulWidget {
  const EcraResponderConcurso({
    super.key,
    this.concurso = const Concurso(
      area: 'Polana Caniço A',
      distancia: '3 km',
      restante: '18 h',
      titulo: 'Substituir canos da casa de banho',
      orcamento: '1 500 MT',
      contagem: 3,
      descricao: 'Canos por baixo do lavatório com fuga. Trocar tubo e sifão.',
    ),
  });

  final Concurso concurso;

  @override
  State<EcraResponderConcurso> createState() => _EstadoEcraResponderConcurso();
}

class _EstadoEcraResponderConcurso extends State<EcraResponderConcurso> {
  bool _contraproposta = true;
  late final int _orcamento = lerMt(widget.concurso.orcamento);
  late final _valor = TextEditingController(text: formatarMt(_orcamento + 300));

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.concurso;
    final diferenca = lerMt(_valor.text) - _orcamento;
    final rotuloDiferenca = diferenca == 0
        ? ''
        : ' · ${diferenca > 0 ? '+' : '−'}${formatarMt(diferenca.abs())}';
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        espaco: 13,
        children: [
          const LinhaTitulo(titulo: 'Concurso'),
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.titulo, style: estiloTexto(16, w: w800)),
                if (t.descricao.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.descricao,
                    style: estiloTexto(13.5, c: CoresApp.corpo, h: 1.45),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Etiqueta(t.area),
                    Etiqueta(t.quando),
                    Etiqueta(t.cliente),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: CoresApp.divisor)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Orçamento do cliente',
                          style: estiloTexto(13, c: CoresApp.atenuado),
                        ),
                      ),
                      Text(t.orcamento, style: estiloTexto(20, w: w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const RotuloCampo('A sua resposta'),
          GrelhaUniforme(
            colunas: 2,
            espacoH: 8,
            children: [
              _Opcao(
                titulo: 'Aceitar',
                subtitulo: 'por ${t.orcamento}',
                seleccionado: !_contraproposta,
                aoTocar: () => setState(() => _contraproposta = false),
              ),
              _Opcao(
                titulo: 'Contraproposta',
                subtitulo: 'outro valor',
                seleccionado: _contraproposta,
                aoTocar: () => setState(() => _contraproposta = true),
              ),
            ],
          ),
          if (_contraproposta) ...[
            ComRotulo(
              rotulo: 'O seu valor',
              child: CampoDinheiro(
                controlador: _valor,
                altura: 54,
                tamanhoFonte: 22,
                destacado: true,
                sufixo: 'MT$rotuloDiferenca',
                aoMudar: (_) => setState(() {}),
              ),
            ),
            const ComRotulo(
              rotulo: 'Porquê este valor?',
              ajuda: 'O cliente vê esta explicação junto do valor.',
              child: CampoTexto(
                altura: 84,
                multilinha: true,
                tamanhoFonte: 14,
                valorInicial:
                    'O orçamento não cobre o material: 2 sifões e tubo PVC novo custam cerca de 300 MT.',
              ),
            ),
          ] else
            const ComRotulo(
              rotulo: 'Mensagem para o cliente',
              dica: '(opcional)',
              child: CampoTexto(
                altura: 84,
                multilinha: true,
                tamanhoFonte: 14,
                textoDica: 'Ex.: Posso ir amanhã de manhã.',
              ),
            ),
          const Spacer(),
          BotaoPrimario(
            _contraproposta
                ? 'Enviar contraproposta'
                : 'Aceitar por ${t.orcamento}',
            aoTocar: () {
              if (_contraproposta && lerMt(_valor.text) <= 0) {
                mostrarAviso(context, 'Indique o seu valor.');
                return;
              }
              mostrarAviso(
                context,
                _contraproposta
                    ? 'Contraproposta enviada.'
                    : 'Proposta enviada.',
              );
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.titulo,
    required this.subtitulo,
    required this.seleccionado,
    required this.aoTocar,
  });

  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final frente = seleccionado ? CoresApp.verdeEscuro : CoresApp.tinta;
    return Toque(
      aoTocar: aoTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? CoresApp.verdeClaro : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? CoresApp.verde : CoresApp.borda,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: estiloTexto(14, w: w800, c: frente),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: estiloTexto(
                12,
                c: seleccionado ? frente : CoresApp.atenuado,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
