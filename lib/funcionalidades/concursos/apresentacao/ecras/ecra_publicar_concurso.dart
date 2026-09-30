import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../comum/widgets/linha_fotos.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/categoria_modelo.dart';
import '../../../catalogo/dados/modelos/servico_modelo.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../../dados/modelos/concurso_modelo.dart';
import '../controladores/concursos_controlador.dart';
import '../widgets/campo_dinheiro.dart';
import 'ecra_propostas.dart';

/// 16 · Cliente · Publicar concurso
///
/// Insere em `concursos` com `fecha_em` = agora + 48 h. A faixa de preços vem
/// de `vw_referencia_precos` por serviço e município; sem linha, não se
/// mostra faixa nenhuma.
class EcraPublicarConcurso extends ConsumerStatefulWidget {
  const EcraPublicarConcurso({super.key});

  @override
  ConsumerState<EcraPublicarConcurso> createState() =>
      _EstadoEcraPublicarConcurso();
}

class _EstadoEcraPublicarConcurso extends ConsumerState<EcraPublicarConcurso> {
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _orcamento = TextEditingController();
  final _outro = TextEditingController();

  static const _outroServico = 'Outro serviço';

  static void _ignorar(String _) {}
  static const _aCarregar = CaixaSeleccao(
    altura: 46,
    valor: 'A carregar…',
    opcoes: [],
    aoMudar: _ignorar,
    activa: false,
  );

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _orcamento.dispose();
    _outro.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto(PublicacaoControlador c) async {
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: 'Fotografia',
    );
    if (opcao == null) return;
    await c.adicionarFoto(
      opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(publicacaoControladorProvider);
    final c = ref.read(publicacaoControladorProvider.notifier);
    ref.listen(publicacaoControladorProvider.select((e) => e.publicado), (
      _,
      publicado,
    ) {
      final id = ref.read(publicacaoControladorProvider).concursoId;
      if (!publicado || id == null) return;
      mostrarAviso(
        context,
        'Concurso publicado. Os prestadores da zona foram notificados.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EcraPropostas(concursoId: id)),
      );
    });
    final fechado = estado.gravado || estado.aEnviar;
    final zonas = ref.watch(zonasProvider);
    final municipio = zonas.valueOrNull
        ?.where((z) => z.id == estado.zonaId)
        .firstOrNull
        ?.municipio;
    final referencia = ref
        .watch(referenciaPrecoProvider((estado.servicoId, municipio)))
        .valueOrNull;

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
            erro: estado.erros['titulo'],
            child: CampoTexto(
              controlador: _titulo,
              altura: 46,
              textoDica: 'Ex.: Substituir canos da casa de banho',
              aoMudar: (_) => c.limparErro('titulo'),
            ),
          ),
          ComRotulo(
            rotulo: 'Categoria',
            erro: estado.erros['categoria'],
            child: VistaLista<CategoriaModelo>(
              valor: ref.watch(categoriasProvider),
              aoRepetir: () => ref.invalidate(categoriasProvider),
              mensagemVazia: 'Ainda não há categorias disponíveis.',
              aCarregar: _aCarregar,
              construir: (categorias) => CaixaSeleccao(
                altura: 46,
                titulo: 'Categoria',
                activa: !fechado,
                valor:
                    categorias
                        .where((x) => x.id == estado.categoriaId)
                        .firstOrNull
                        ?.nome ??
                    'Escolher',
                opcoes: [for (final x in categorias) x.nome],
                aoMudar: (nome) => c.escolherCategoria(
                  categorias.firstWhere((x) => x.nome == nome).id,
                ),
              ),
            ),
          ),
          if (estado.categoriaId != null)
            ComRotulo(
              rotulo: 'Serviço',
              erro: estado.erros['servico'],
              child: VistaLista<ServicoModelo>(
                valor: ref.watch(servicosProvider),
                aoRepetir: () => ref.invalidate(servicosProvider),
                mensagemVazia: 'Ainda não há serviços disponíveis.',
                aCarregar: _aCarregar,
                construir: (todos) {
                  final servicos = servicosDaCategoria(
                    todos,
                    estado.categoriaId!,
                  );
                  // "Outro serviço" fica sempre no fim, mesmo sem serviços
                  // no catálogo desta categoria.
                  return CaixaSeleccao(
                    altura: 46,
                    titulo: 'Serviço',
                    activa: !fechado,
                    valor: estado.outroServico
                        ? _outroServico
                        : servicos
                                  .where((s) => s.id == estado.servicoId)
                                  .firstOrNull
                                  ?.nome ??
                              'Escolher',
                    opcoes: [for (final s in servicos) s.nome, _outroServico],
                    aoMudar: (nome) => nome == _outroServico
                        ? c.escolherOutroServico()
                        : c.escolherServico(
                            servicos.firstWhere((s) => s.nome == nome).id,
                          ),
                  );
                },
              ),
            ),
          if (estado.outroServico)
            ComRotulo(
              rotulo: 'Que serviço precisa?',
              erro: estado.erros['outro'],
              ajuda: 'Os prestadores da categoria vêem isto no concurso.',
              child: CampoTexto(
                controlador: _outro,
                altura: 46,
                textoDica: 'Ex.: Montar um toldo na varanda',
                aoMudar: (_) => c.limparErro('outro'),
              ),
            ),
          ComRotulo(
            rotulo: 'Descrição',
            erro: estado.erros['descricao'],
            child: CampoTexto(
              controlador: _descricao,
              altura: 70,
              multilinha: true,
              tamanhoFonte: 14,
              textoDica: 'Ex.: Canos por baixo do lavatório com fuga.',
              aoMudar: (_) => c.limparErro('descricao'),
            ),
          ),
          ComRotulo(
            rotulo: 'O seu orçamento',
            erro: estado.erros['orcamento'],
            // Só com linha na vista; com poucos prestadores, inventar um
            // intervalo seria enganar o cliente.
            ajuda: referencia == null || municipio == null
                ? null
                : 'Serviços parecidos em $municipio: '
                      '${formatarMt(referencia.minimo)} – '
                      '${formatarMt(referencia.maximo)} MT',
            child: CampoDinheiro(
              controlador: _orcamento,
              altura: 60,
              tamanhoFonte: 26,
              destacado: true,
              aoMudar: (_) => c.limparErro('orcamento'),
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
                  activa: !fechado,
                  valor: estado.quando.rotulo,
                  opcoes: [for (final u in Urgencia.values) u.rotulo],
                  aoMudar: (v) => c.escolherQuando(
                    Urgencia.values.firstWhere((u) => u.rotulo == v),
                  ),
                ),
              ),
              ComRotulo(
                rotulo: 'Bairro',
                erro: estado.erros['zona'],
                child: VistaLista<ZonaModelo>(
                  valor: zonas,
                  aoRepetir: () => ref.invalidate(zonasProvider),
                  mensagemVazia: 'Sem bairros.',
                  aCarregar: _aCarregar,
                  construir: (lista) => CaixaSeleccao(
                    altura: 46,
                    tamanhoFonte: 14,
                    titulo: 'Bairro',
                    activa: !fechado,
                    valor:
                        lista
                            .where((z) => z.id == estado.zonaId)
                            .firstOrNull
                            ?.nome ??
                        'Escolher',
                    opcoes: [
                      for (final z in lista) '${z.nome}, ${z.municipio}',
                    ],
                    aoMudar: (v) => c.escolherZona(
                      lista
                          .firstWhere((z) => '${z.nome}, ${z.municipio}' == v)
                          .id,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Recebe propostas durante 48 horas.',
            style: estiloTexto(12.5, c: CoresApp.atenuado),
          ),
          LinhaFotos(
            contagem: 0,
            tamanho: 48,
            miniaturas: [for (final f in estado.fotos) f.bytes],
            aoTocarMiniatura: fechado ? null : c.removerFoto,
            aoAdicionar: fechado ? () {} : () => _escolherFoto(c),
            elementoFinal: Text(
              'Fotografias (opcional)',
              style: estiloTexto(13, c: CoresApp.atenuado),
            ),
          ),
          if (estado.erroEnvio != null) MensagemErro(estado.erroEnvio!),
          const Spacer(),
          if (estado.gravado && estado.erroEnvio != null && !estado.aEnviar)
            BotaoContorno(
              'Continuar sem as fotografias',
              aoTocar: c.terminarSemFotografias,
            ),
          BotaoPrimario(
            estado.aEnviar
                ? (estado.etapa ?? 'A publicar…')
                : estado.gravado
                ? 'Tentar enviar as fotografias'
                : 'Publicar concurso',
            aoTocar: estado.aEnviar
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    c.publicar(
                      titulo: _titulo.text,
                      descricao: _descricao.text,
                      orcamento: _orcamento.text,
                      outroServico: _outro.text,
                    );
                  },
          ),
        ],
      ),
    );
  }
}
