import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/caixa_escolha.dart';
import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/ecras/ecra_encaminhamento.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/categoria_modelo.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../controladores/cadastro_prestador_controlador.dart';
import '../controladores/cadastro_prestador_estado.dart';
import '../widgets/cabecalho_passo.dart';
import '../widgets/cartao_documento.dart';
import '../widgets/lista_etapas_envio.dart';

/// Cadastro do prestador: serviço, zonas, documentos e envio.
///
/// Nome, telefone e bairro já estão no perfil desde o registo; aqui só entra
/// o que é próprio do prestador. Exige sessão.
class EcraCadastroPrestador extends ConsumerStatefulWidget {
  const EcraCadastroPrestador({super.key});

  @override
  ConsumerState<EcraCadastroPrestador> createState() =>
      _EstadoEcraCadastroPrestador();
}

class _EstadoEcraCadastroPrestador
    extends ConsumerState<EcraCadastroPrestador> {
  late final _bio = TextEditingController(
    text: ref.read(cadastroPrestadorControladorProvider).bio,
  );
  late final _anos = TextEditingController(
    text: ref.read(cadastroPrestadorControladorProvider).anos,
  );

  @override
  void dispose() {
    _bio.dispose();
    _anos.dispose();
    super.dispose();
  }

  CadastroPrestadorControlador get _controlador =>
      ref.read(cadastroPrestadorControladorProvider.notifier);

  void _avancar() {
    FocusScope.of(context).unfocus();
    _controlador.avancar();
  }

  Future<void> _escolher(TipoDocumento tipo) async {
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: tipo.rotulo,
    );
    if (opcao == null) return;
    await _controlador.escolherDocumento(
      tipo,
      opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      cadastroPrestadorControladorProvider.select((estado) => estado.enviado),
      (_, enviado) {
        if (!enviado) return;
        mostrarAviso(
          context,
          'Cadastro enviado. Avisamos quando for aprovado.',
        );
        reiniciarCom(context, const EcraEncaminhamento());
      },
    );
    final estado = ref.watch(cadastroPrestadorControladorProvider);

    return PopScope(
      canPop: estado.passo == PassoCadastroPrestador.servico && !estado.aEnviar,
      onPopInvokedWithResult: (saiu, _) {
        if (saiu || estado.aEnviar) return;
        if (!_controlador.recuar()) Navigator.of(context).pop();
      },
      child: EcraBase(
        barraInferior: _BarraAccoes(
          estado: estado,
          aoAvancar: _avancar,
          aoRepetir: _controlador.repetirEnvio,
        ),
        child: ScrollPreenchido(
          preenchimento: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          espaco: 18,
          children: [
            Row(
              children: [
                BotaoVoltar(
                  aoTocar: estado.aEnviar
                      ? () {}
                      : () {
                          if (!_controlador.recuar()) {
                            Navigator.of(context).maybePop();
                          }
                        },
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Registar-se como prestador',
                    overflow: TextOverflow.ellipsis,
                    style: estiloTexto(16, w: w800),
                  ),
                ),
              ],
            ),
            ...switch (estado.passo) {
              PassoCadastroPrestador.servico => _passoServico(estado),
              PassoCadastroPrestador.zonas => _passoZonas(estado),
              PassoCadastroPrestador.documentos => _passoDocumentos(estado),
              PassoCadastroPrestador.envio => _passoEnvio(estado),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _passoServico(CadastroPrestadorEstado estado) => [
    CabecalhoPasso(
      indice: estado.indicePasso,
      total: CadastroPrestadorEstado.totalPassos,
      titulo: 'O que faz',
      apoio: 'Escolha o serviço principal. Só recebe pedidos desse serviço.',
    ),
    ComRotulo(
      rotulo: 'Serviço que presta',
      erro: estado.erros['categoria'],
      espaco: 10,
      child: VistaLista<CategoriaModelo>(
        valor: ref.watch(categoriasProvider),
        aoRepetir: () => ref.invalidate(categoriasProvider),
        mensagemVazia: 'Ainda não há serviços disponíveis.',
        construir: (categorias) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: comEspaco([
            for (final categoria in categorias)
              CaixaEscolha(
                rotulo: categoria.nome,
                seleccionado: categoria.id == estado.categoriaId,
                aoTocar: () => _controlador.escolherCategoria(categoria.id),
              ),
          ], 8),
        ),
      ),
    ),
    ComRotulo(
      rotulo: 'Anos de experiência',
      dica: '(opcional)',
      erro: estado.erros['anos'],
      child: CampoTexto(
        controlador: _anos,
        tipoTeclado: TextInputType.number,
        textoDica: 'Ex.: 8',
        aoMudar: _controlador.definirAnos,
      ),
    ),
    ComRotulo(
      rotulo: 'Sobre o seu trabalho',
      dica: '(opcional)',
      erro: estado.erros['bio'],
      child: CampoTexto(
        controlador: _bio,
        altura: 96,
        multilinha: true,
        tamanhoFonte: 14,
        textoDica: 'Ex.: Instalações e reparações eléctricas, com garantia.',
        aoMudar: _controlador.definirBio,
      ),
    ),
  ];

  List<Widget> _passoZonas(CadastroPrestadorEstado estado) => [
    CabecalhoPasso(
      indice: estado.indicePasso,
      total: CadastroPrestadorEstado.totalPassos,
      titulo: 'Onde atende',
      apoio: 'Só recebe pedidos das zonas que escolher aqui.',
    ),
    Row(
      children: [
        Expanded(
          child: Text('Zonas onde atende', style: estiloTexto(13, w: w700)),
        ),
        Text(
          estado.zonas.isEmpty
              ? 'Nenhuma'
              : '${estado.zonas.length} escolhida${estado.zonas.length == 1 ? '' : 's'}',
          style: estiloTexto(
            13,
            w: w700,
            c: estado.zonas.isEmpty ? CoresApp.atenuado : CoresApp.verde,
          ),
        ),
      ],
    ),
    VistaLista<ZonaModelo>(
      valor: ref.watch(zonasProvider),
      aoRepetir: () => ref.invalidate(zonasProvider),
      mensagemVazia: 'Ainda não há zonas disponíveis.',
      construir: (zonas) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: comEspaco([
          for (final municipio in municipiosDe(zonas))
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  municipio,
                  style: estiloTexto(12.5, w: w700, c: CoresApp.atenuado),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final zona in zonasDoMunicipio(zonas, municipio))
                      Pilula(
                        zona.nome,
                        seleccionado: estado.zonas.contains(zona.id),
                        aoTocar: () => _controlador.alternarZona(zona.id),
                      ),
                  ],
                ),
              ],
            ),
        ], 16),
      ),
    ),
    if (estado.erros['zonas'] != null) MensagemErro(estado.erros['zonas']!),
  ];

  List<Widget> _passoDocumentos(CadastroPrestadorEstado estado) => [
    CabecalhoPasso(
      indice: estado.indicePasso,
      total: CadastroPrestadorEstado.totalPassos,
      titulo: 'Documentos',
      apoio:
          'Confirmamos a sua identidade antes de o mostrar aos clientes. '
          'Só a foto de perfil fica visível.',
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comEspaco([
        _cartao(
          estado,
          TipoDocumento.fotoPerfil,
          'Rosto visível, sem óculos escuros',
        ),
        _cartao(estado, TipoDocumento.biFrente, 'Todo o BI dentro da foto'),
        _cartao(
          estado,
          TipoDocumento.biVerso,
          'Opcional. Acelera a aprovação',
          titulo: 'BI, verso (opcional)',
        ),
      ], 10),
    ),
    if (estado.erros['documentos'] != null)
      MensagemErro(estado.erros['documentos']!),
    Text(
      'Os documentos são vistos apenas pela equipa que aprova os cadastros. '
      'As fotografias são reduzidas antes do envio, para gastar menos dados.',
      style: estiloTexto(12.5, c: CoresApp.atenuado, h: 1.45),
    ),
  ];

  Widget _cartao(
    CadastroPrestadorEstado estado,
    TipoDocumento tipo,
    String apoio, {
    String? titulo,
  }) => CartaoDocumento(
    titulo: titulo ?? tipo.rotulo,
    apoio: apoio,
    imagem: estado.documentos[tipo],
    aoEscolher: () => _escolher(tipo),
    aoRemover: () => _controlador.removerDocumento(tipo),
  );

  List<Widget> _passoEnvio(CadastroPrestadorEstado estado) {
    final falhou = estado.erroEnvio != null;
    return [
      Text(
        falhou ? 'O envio parou' : 'A enviar o cadastro',
        style: estiloTexto(26, w: w800, ls: -0.02),
      ),
      Text(
        falhou
            ? 'O que já foi enviado fica guardado. Tentar de novo continua '
                  'a partir daqui.'
            : 'Não feche a app. Com dados móveis pode demorar um pouco.',
        style: estiloTexto(14, c: CoresApp.atenuado, h: 1.45),
      ),
      ListaEtapasEnvio(
        etapas: estado.etapas,
        concluidas: estado.etapasConcluidas,
        actual: estado.etapaActual,
        falhou: falhou,
      ),
      if (falhou) MensagemErro(estado.erroEnvio!),
    ];
  }
}

class _BarraAccoes extends StatelessWidget {
  const _BarraAccoes({
    required this.estado,
    required this.aoAvancar,
    required this.aoRepetir,
  });

  final CadastroPrestadorEstado estado;
  final VoidCallback aoAvancar;
  final VoidCallback aoRepetir;

  @override
  Widget build(BuildContext context) {
    final (rotulo, accao) = switch (estado.passo) {
      PassoCadastroPrestador.servico ||
      PassoCadastroPrestador.zonas => ('Continuar', aoAvancar),
      PassoCadastroPrestador.documentos => ('Enviar cadastro', aoAvancar),
      PassoCadastroPrestador.envio when estado.aEnviar => ('A enviar…', null),
      PassoCadastroPrestador.envio when estado.erroEnvio != null => (
        'Tentar de novo',
        aoRepetir,
      ),
      PassoCadastroPrestador.envio => ('Enviado', null),
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CoresApp.borda)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: BotaoPrimario(rotulo, aoTocar: accao),
        ),
      ),
    );
  }
}
