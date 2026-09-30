import 'package:flutter/material.dart';

import '../../../../comum/dados/dados_exemplo.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import 'ecra_prestador_escolhido.dart';

/// 19 · Cliente · Escolher prestador
class EcraPropostas extends StatefulWidget {
  const EcraPropostas({
    super.key,
    this.titulo = 'Substituir canos da casa de banho',
    this.orcamento = '1 500 MT',
  });

  final String titulo;
  final String orcamento;

  @override
  State<EcraPropostas> createState() => _EstadoEcraPropostas();
}

class _EstadoEcraPropostas extends State<EcraPropostas> {
  String _ordenacao = 'Melhor avaliados';

  @override
  Widget build(BuildContext context) {
    final lista = [...DadosExemplo.propostas];
    if (_ordenacao == 'Melhor avaliados')
      lista.sort((a, b) => b.avaliacao.compareTo(a.avaliacao));
    if (_ordenacao == 'Mais baratos')
      lista.sort((a, b) => lerMt(a.preco).compareTo(lerMt(b.preco)));
    return EcraBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: CoresApp.borda)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaTitulo(
                  titulo: widget.titulo,
                  subtitulo: 'Orçamento ${widget.orcamento} · fecha em 18 h',
                  tamanhoTitulo: 16,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${lista.length} propostas',
                        style: estiloTexto(13, w: w700),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final v = await escolherOpcao(
                          context,
                          const ['Melhor avaliados', 'Mais baratos'],
                          _ordenacao,
                          titulo: 'Ordenar por',
                        );
                        if (v != null) setState(() => _ordenacao = v);
                      },
                      child: Text(
                        '$_ordenacao ▾',
                        style: estiloTexto(13, w: w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _CartaoProposta(lista[i], servico: widget.titulo),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoProposta extends StatelessWidget {
  const _CartaoProposta(this.p, {required this.servico});

  final Proposta p;
  final String servico;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      preenchimento: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          Row(
            children: [
              const Riscado(largura: 40, altura: 40, raio: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.nome,
                            style: estiloTexto(14.5, w: w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const PontoVerificado(tamanho: 15),
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '★',
                            style: estiloTexto(12, c: CoresApp.estrela),
                          ),
                          TextSpan(
                            text: ' ${p.avaliacao} · ${p.servicos} serviços',
                            style: estiloTexto(12, c: CoresApp.atenuado),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(p.preco, style: estiloTexto(17, w: w800)),
                  Selo(
                    p.tipo.rotulo,
                    fundo: p.tipo.fundo,
                    frente: p.tipo.frente,
                    tamanhoFonte: 11,
                    raio: 8,
                    preenchimento: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: CoresApp.areiaClara,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              p.justificacao,
              style: estiloTexto(13, c: CoresApp.corpo, h: 1.45),
            ),
          ),
          GrelhaUniforme(
            colunas: 2,
            espacoH: 8,
            flex: const [10, 14],
            children: [
              BotaoContorno(
                'Ver perfil',
                altura: 40,
                raio: 11,
                tamanhoFonte: 13.5,
                // TODO(passo 8): as propostas de exemplo não têm o id do
                // prestador; com os concursos ligados, abre
                // EcraPerfilPrestador(prestadorId: …).
                aoTocar: () => mostrarAviso(
                  context,
                  'O perfil fica disponível quando os concursos estiverem ligados.',
                ),
              ),
              BotaoPrimario(
                'Escolher',
                altura: 40,
                raio: 11,
                tamanhoFonte: 13.5,
                aoTocar: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => EcraPrestadorEscolhido(
                      nome: p.nome,
                      servico: servico,
                      preco: p.preco,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ], 9),
      ),
    );
  }
}
