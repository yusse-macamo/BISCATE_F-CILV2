import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../controladores/precos_controlador.dart';

/// 13 · Serviços e preços
///
/// Cada alteração é gravada sozinha, pouco depois de parar de escrever ou ao
/// sair do campo. Campo em branco é "sob orçamento".
class EcraPrecos extends ConsumerStatefulWidget {
  const EcraPrecos({super.key, this.aoVoltar});

  final VoidCallback? aoVoltar;

  @override
  ConsumerState<EcraPrecos> createState() => _EstadoEcraPrecos();
}

class _EstadoEcraPrecos extends ConsumerState<EcraPrecos> {
  final _nomeNovo = TextEditingController();
  final _valorNovo = TextEditingController();

  @override
  void dispose() {
    _nomeNovo.dispose();
    _valorNovo.dispose();
    super.dispose();
  }

  PrecosControlador get _controlador =>
      ref.read(precosControladorProvider.notifier);

  Future<void> _adicionar() async {
    FocusScope.of(context).unfocus();
    final adicionado = await _controlador.adicionarServicoProprio(
      nome: _nomeNovo.text,
      valorTexto: _valorNovo.text,
    );
    if (adicionado) {
      _nomeNovo.clear();
      _valorNovo.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cabecalho = [
      Row(
        children: [
          BotaoVoltar(aoTocar: widget.aoVoltar),
          const SizedBox(width: 12),
          Text('Serviços e preços', style: estiloTexto(18, w: w800)),
        ],
      ),
      Text(
        'Preços visíveis ajudam o cliente a decidir. Indique o valor inicial '
        'de cada serviço, ou deixe em branco para "sob orçamento". As '
        'alterações são guardadas automaticamente.',
        style: estiloTexto(14, c: CoresApp.atenuado, h: 1.45),
      ),
    ];

    return EcraBase(
      child: ref
          .watch(precosControladorProvider)
          .when(
            loading: () => ScrollPreenchido(
              preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              children: [...cabecalho, const EstadoCarregar()],
            ),
            error: (erro, _) => ScrollPreenchido(
              preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              children: [
                ...cabecalho,
                EstadoErro(
                  mensagem: mensagemDe(erro),
                  aoRepetir: () => ref.invalidate(precosControladorProvider),
                ),
              ],
            ),
            data: (estado) => ScrollPreenchido(
              preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              children: [
                ...cabecalho,
                if (estado.semRegisto)
                  const EstadoVazio(
                    'Ainda não tem registo de prestador. Registe-se em Conta '
                    'para indicar os seus preços.',
                  )
                else ...[
                  ..._catalogo(estado),
                  ..._proprios(estado),
                ],
              ],
            ),
          ),
    );
  }

  List<Widget> _catalogo(EstadoPrecos estado) => [
    if (estado.servicos.isEmpty)
      const EstadoVazio('Ainda não há serviços no catálogo da sua categoria.'),
    for (final servico in estado.servicos)
      _LinhaPreco(
        key: ValueKey(EstadoPrecos.chaveCatalogo(servico.id)),
        nome: servico.nome,
        temRegisto: estado.precos.containsKey(servico.id),
        valor: estado.precos[servico.id],
        chave: EstadoPrecos.chaveCatalogo(servico.id),
        estado: estado,
        aoMudar: (texto) =>
            _controlador.alterarPrecoCatalogo(servico.id, texto),
      ),
  ];

  List<Widget> _proprios(EstadoPrecos estado) => [
    Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('Fora do catálogo', style: estiloTexto(16, w: w800)),
    ),
    Text(
      'Serviços que faz e não estão na lista acima. Até 3.',
      style: estiloTexto(13, c: CoresApp.atenuado, h: 1.4),
    ),
    for (final servico in estado.proprios)
      _LinhaPreco(
        key: ValueKey(EstadoPrecos.chaveProprio(servico.id)),
        nome: servico.nome,
        temRegisto: true,
        valor: servico.valor,
        chave: EstadoPrecos.chaveProprio(servico.id),
        estado: estado,
        aoMudar: (texto) => _controlador.alterarPrecoProprio(servico.id, texto),
        aoRemover: () => _controlador.removerServicoProprio(servico.id),
      ),
    if (estado.erroProprios != null) MensagemErro(estado.erroProprios!),
    Cartao(
      corBorda: CoresApp.tracejado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          ComRotulo(
            rotulo: 'Nome do serviço',
            erro: estado.errosNovo['nome'],
            child: CampoTexto(
              controlador: _nomeNovo,
              altura: 44,
              tamanhoFonte: 14,
              textoDica: 'Ex.: Montagem de antena',
            ),
          ),
          ComRotulo(
            rotulo: 'Valor',
            dica: '(em branco: sob orçamento)',
            erro: estado.errosNovo['valor'],
            child: CampoTexto(
              controlador: _valorNovo,
              altura: 44,
              tamanhoFonte: 14,
              tipoTeclado: TextInputType.number,
              textoDica: 'Ex.: 500',
              sufixo: Text(' MT', style: estiloTexto(14, w: w800)),
            ),
          ),
          if (estado.errosNovo['geral'] != null)
            MensagemErro(estado.errosNovo['geral']!),
          BotaoContorno(
            estado.aAdicionar ? 'A adicionar…' : '+ Adicionar serviço',
            altura: 46,
            tamanhoFonte: 14,
            cor: CoresApp.verde,
            aoTocar: estado.aAdicionar ? null : _adicionar,
          ),
        ], 12),
      ),
    ),
  ];
}

/// Um serviço com o seu preço editável e a situação da gravação.
class _LinhaPreco extends ConsumerWidget {
  const _LinhaPreco({
    super.key,
    required this.nome,
    required this.temRegisto,
    required this.valor,
    required this.chave,
    required this.estado,
    required this.aoMudar,
    this.aoRemover,
  });

  final String nome;
  final bool temRegisto;
  final int? valor;
  final String chave;
  final EstadoPrecos estado;
  final ValueChanged<String> aoMudar;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlador = ref.read(precosControladorProvider.notifier);
    final situacao = estado.gravacoes[chave];
    final erroCampo = estado.errosCampo[chave];
    final estiloApoio = estiloTexto(12.5, c: CoresApp.atenuado);

    final Widget apoio = switch (situacao) {
      SituacaoGravacao.aGuardar => Text('A guardar…', style: estiloApoio),
      SituacaoGravacao.erro => GestureDetector(
        onTap: () => controlador.repetir(chave),
        child: MensagemErro(
          '${estado.errosGravacao[chave] ?? mensagemInesperada} '
          'Tocar para tentar de novo.',
        ),
      ),
      SituacaoGravacao.guardado => Text(
        valor == null ? 'Guardado · sob orçamento' : 'Guardado',
        style: estiloTexto(12.5, w: w600, c: CoresApp.verde),
      ),
      null => Text(
        !temRegisto
            ? 'Sem preço indicado'
            : valor == null
            ? 'Sob orçamento'
            : 'Preço inicial',
        style: estiloApoio,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoresApp.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: estiloTexto(15, w: w800)),
                    const SizedBox(height: 2),
                    apoio,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: _CampoPreco(
                  inicial: valor,
                  aoMudar: aoMudar,
                  aoConfirmar: () => controlador.confirmar(chave),
                ),
              ),
            ],
          ),
          if (erroCampo != null) ...[
            const SizedBox(height: 8),
            MensagemErro(erroCampo),
          ],
          if (aoRemover != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: aoRemover,
                child: Text(
                  'Remover',
                  style: estiloTexto(13, w: w700, c: CoresApp.rejeitar),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampoPreco extends StatefulWidget {
  const _CampoPreco({
    required this.inicial,
    required this.aoMudar,
    required this.aoConfirmar,
  });

  /// Nulo mostra o campo em branco ("sob orçamento" ou sem preço).
  final int? inicial;
  final ValueChanged<String> aoMudar;

  /// O campo perdeu o foco: grava já, sem esperar.
  final VoidCallback aoConfirmar;

  @override
  State<_CampoPreco> createState() => _EstadoCampoPreco();
}

class _EstadoCampoPreco extends State<_CampoPreco> {
  late final _controlador = TextEditingController(
    text: widget.inicial == null ? '' : formatarMt(widget.inicial!),
  );
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) {
        final texto = _controlador.text.trim();
        final valor = lerMt(texto);
        if (texto.isNotEmpty && valor > 0) {
          _controlador.text = formatarMt(valor);
        }
        widget.aoConfirmar();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = _foco.hasFocus;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: CoresApp.pagina,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activo ? CoresApp.verde : CoresApp.borda,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controlador,
              focusNode: _foco,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              onChanged: widget.aoMudar,
              style: estiloTexto(15, w: w800, c: CoresApp.tinta),
              decoration: InputDecoration.collapsed(
                hintText: '—',
                hintStyle: estiloTexto(15, w: w800, c: CoresApp.atenuado),
              ),
            ),
          ),
          Text(' MT', style: estiloTexto(15, w: w800)),
        ],
      ),
    );
  }
}
