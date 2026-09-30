import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../comum/widgets/linha_fotos.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/categoria_modelo.dart';
import '../widgets/campo_dinheiro.dart';
import 'ecra_propostas.dart';

/// 16 · Cliente · Publicar concurso
class EcraPublicarConcurso extends ConsumerStatefulWidget {
  const EcraPublicarConcurso({super.key});

  @override
  ConsumerState<EcraPublicarConcurso> createState() =>
      _EstadoEcraPublicarConcurso();
}

class _EstadoEcraPublicarConcurso extends ConsumerState<EcraPublicarConcurso> {
  /// O `id` da categoria escolhida, não o nome.
  String? _categoriaId;
  String _quando = 'Esta semana';
  String _prazo = '48 horas';
  int _fotos = 1;
  final _titulo = TextEditingController(
    text: 'Substituir canos da casa de banho',
  );
  final _orcamento = TextEditingController(text: '1 500');

  static void _ignorar(String _) {}

  @override
  void dispose() {
    _titulo.dispose();
    _orcamento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        espaco: 13,
        children: [
          const LinhaTitulo(
            titulo: 'Publicar concurso',
            subtitulo: 'Receba propostas de vários prestadores',
          ),
          ComRotulo(
            rotulo: 'O que precisa?',
            child: CampoTexto(controlador: _titulo, altura: 46),
          ),
          ComRotulo(
            rotulo: 'Categoria',
            child: VistaLista<CategoriaModelo>(
              valor: ref.watch(categoriasProvider),
              aoRepetir: () => ref.invalidate(categoriasProvider),
              mensagemVazia: 'Ainda não há categorias disponíveis.',
              aCarregar: const CaixaSeleccao(
                altura: 46,
                valor: 'A carregar…',
                opcoes: [],
                aoMudar: _ignorar,
                activa: false,
              ),
              construir: (categorias) => CaixaSeleccao(
                altura: 46,
                titulo: 'Categoria',
                valor:
                    categorias
                        .where((c) => c.id == _categoriaId)
                        .firstOrNull
                        ?.nome ??
                    'Escolher',
                opcoes: [for (final c in categorias) c.nome],
                aoMudar: (nome) => setState(
                  () => _categoriaId = categorias
                      .firstWhere((c) => c.nome == nome)
                      .id,
                ),
              ),
            ),
          ),
          const ComRotulo(
            rotulo: 'Descrição',
            child: CampoTexto(
              altura: 70,
              multilinha: true,
              tamanhoFonte: 14,
              valorInicial:
                  'Canos por baixo do lavatório com fuga. Trocar tubo e sifão.',
            ),
          ),
          ComRotulo(
            rotulo: 'O seu orçamento',
            ajuda: 'Serviços parecidos em Maputo: 1 200 – 2 000 MT',
            child: CampoDinheiro(
              controlador: _orcamento,
              altura: 60,
              tamanhoFonte: 26,
              destacado: true,
            ),
          ),
          GrelhaUniforme(
            colunas: 2,
            children: [
              ComRotulo(
                rotulo: 'Quando',
                child: CaixaSeleccao(
                  altura: 46,
                  tamanhoFonte: 14,
                  mostrarSeta: false,
                  titulo: 'Quando',
                  valor: _quando,
                  opcoes: const [
                    'Hoje',
                    'Esta semana',
                    'Próxima semana',
                    'Sem pressa',
                  ],
                  aoMudar: (v) => setState(() => _quando = v),
                ),
              ),
              ComRotulo(
                rotulo: 'Propostas até',
                child: CaixaSeleccao(
                  altura: 46,
                  tamanhoFonte: 14,
                  mostrarSeta: false,
                  titulo: 'Receber propostas durante',
                  valor: _prazo,
                  opcoes: const [
                    '24 horas',
                    '48 horas',
                    '72 horas',
                    '1 semana',
                  ],
                  aoMudar: (v) => setState(() => _prazo = v),
                ),
              ),
            ],
          ),
          LinhaFotos(
            contagem: _fotos,
            tamanho: 48,
            aoAdicionar: () => setState(() => _fotos++),
            elementoFinal: Text(
              'Polana Caniço A, Rua 4',
              style: estiloTexto(13, c: CoresApp.atenuado),
            ),
          ),
          const Spacer(),
          BotaoPrimario(
            'Publicar concurso',
            aoTocar: () {
              final orcamento = lerMt(_orcamento.text);
              if (orcamento <= 0) {
                mostrarAviso(context, 'Indique o seu orçamento.');
                return;
              }
              mostrarAviso(
                context,
                'Concurso publicado. Os prestadores da zona foram notificados.',
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EcraPropostas(
                    titulo: _titulo.text.trim().isEmpty
                        ? 'Concurso'
                        : _titulo.text.trim(),
                    orcamento: '${formatarMt(orcamento)} MT',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
