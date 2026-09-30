import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/modelos/concurso_modelo.dart';
import '../controladores/concursos_controlador.dart';
import '../widgets/campo_dinheiro.dart';

/// 18 · Prestador · Responder a um concurso
///
/// Insere em `propostas`, com `tipo` `aceita_orcamento` ou `contraproposta`.
/// A contraproposta exige justificação de pelo menos 15 caracteres: a base
/// impõe-no, e o formulário valida antes de enviar.
class EcraResponderConcurso extends ConsumerStatefulWidget {
  const EcraResponderConcurso({super.key, required this.concursoId});

  final String concursoId;

  @override
  ConsumerState<EcraResponderConcurso> createState() =>
      _EstadoEcraResponderConcurso();
}

class _EstadoEcraResponderConcurso
    extends ConsumerState<EcraResponderConcurso> {
  final _valor = TextEditingController();
  final _justificacao = TextEditingController();

  @override
  void dispose() {
    _valor.dispose();
    _justificacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final concurso = ref.watch(concursoProvider(widget.concursoId));
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        espaco: 13,
        children: [
          const LinhaTitulo(titulo: 'Concurso'),
          ...concurso.when(
            loading: () => const [EstadoCarregar()],
            error: (erro, _) => [
              EstadoErro(
                mensagem: mensagemDe(erro),
                aoRepetir: () =>
                    ref.invalidate(concursoProvider(widget.concursoId)),
              ),
            ],
            data: (t) => t == null
                ? const [EstadoVazio('Este concurso já não está disponível.')]
                : _conteudo(t),
          ),
        ],
      ),
    );
  }

  List<Widget> _conteudo(ConcursoModelo t) {
    final provider = respostaControladorProvider(widget.concursoId);
    final estado = ref.watch(provider);
    final c = ref.read(provider.notifier);
    ref.listen(provider.select((e) => e.enviada), (_, enviada) {
      if (!enviada) return;
      mostrarAviso(
        context,
        estado.tipo == TipoProposta.contraproposta
            ? 'Contraproposta enviada.'
            : 'Proposta enviada.',
      );
      Navigator.of(context).maybePop();
    });

    final contra = estado.tipo == TipoProposta.contraproposta;
    final orcamento = t.orcamento ?? 0;
    final diferenca = lerMt(_valor.text) - orcamento;
    final rotuloDiferenca = diferenca == 0 || _valor.text.trim().isEmpty
        ? ''
        : ' · ${diferenca > 0 ? '+' : '−'}${formatarMt(diferenca.abs())}';
    final aberto = t.estado == EstadoConcurso.aberto;

    return [
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
                if (t.zona case final z?) Etiqueta(z),
                if (t.quando case final q?) Etiqueta(q.rotulo),
                if (t.servico case final s?) Etiqueta(s),
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
                  Text(
                    textoOrcamento(t.orcamento),
                    style: estiloTexto(20, w: w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (t.clienteId != null &&
          t.clienteId == ref.read(autenticacaoRepositorioProvider).utilizadorId)
        const EstadoVazio('Este concurso é seu: não lhe pode responder.')
      else if (t.jaRespondido)
        const EstadoVazio('Já respondeu a este concurso.')
      else if (!aberto)
        EstadoVazio(
          'Este concurso já não aceita propostas (${t.estado.rotulo.toLowerCase()}).',
        )
      else ...[
        const RotuloCampo('A sua resposta'),
        GrelhaUniforme(
          colunas: 2,
          espacoH: 8,
          children: [
            _Opcao(
              titulo: 'Aceitar',
              subtitulo: 'por ${textoOrcamento(t.orcamento)}',
              seleccionado: !contra,
              aoTocar: () => c.escolherTipo(TipoProposta.aceitaOrcamento),
            ),
            _Opcao(
              titulo: 'Contraproposta',
              subtitulo: 'outro valor',
              seleccionado: contra,
              aoTocar: () => c.escolherTipo(TipoProposta.contraproposta),
            ),
          ],
        ),
        if (contra)
          ComRotulo(
            rotulo: 'O seu valor',
            erro: estado.erros['valor'],
            child: CampoDinheiro(
              controlador: _valor,
              altura: 54,
              tamanhoFonte: 22,
              destacado: true,
              sufixo: 'MT$rotuloDiferenca',
              aoMudar: (_) {
                c.limparErro('valor');
                setState(() {});
              },
            ),
          )
        else if (estado.erros['valor'] case final e?)
          MensagemErro(e),
        ComRotulo(
          rotulo: contra ? 'Porquê este valor?' : 'Mensagem para o cliente',
          dica: contra ? null : '(opcional)',
          ajuda: contra ? 'O cliente vê esta explicação junto do valor.' : null,
          erro: estado.erros['justificacao'],
          child: CampoTexto(
            controlador: _justificacao,
            altura: 84,
            multilinha: true,
            tamanhoFonte: 14,
            textoDica: contra
                ? 'Ex.: O orçamento não cobre o material.'
                : 'Ex.: Posso ir amanhã de manhã.',
            aoMudar: (_) => c.limparErro('justificacao'),
          ),
        ),
        if (estado.erroEnvio != null) MensagemErro(estado.erroEnvio!),
        const Spacer(),
        BotaoPrimario(
          estado.aEnviar
              ? 'A enviar…'
              : contra
              ? 'Enviar contraproposta'
              : 'Aceitar por ${textoOrcamento(t.orcamento)}',
          aoTocar: estado.aEnviar
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  c.enviar(
                    concurso: t,
                    valorTexto: _valor.text,
                    justificacao: _justificacao.text,
                  );
                },
        ),
      ],
    ];
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
