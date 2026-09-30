import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../../../cliente/apresentacao/widgets/foto_prestador.dart';
import '../../dados/modelos/perfil_editavel_modelo.dart';
import '../controladores/editar_perfil_controlador.dart';
import '../controladores/portfolio_controlador.dart';
import 'ecra_portfolio.dart';

/// 11 · Perfil profissional
///
/// Lê e grava os dados reais do prestador autenticado: profissão (título),
/// descrição, experiência e zonas em `prestadores`/`prestador_zonas`, e o
/// telefone e a foto em `perfis`.
class EcraEditarPerfil extends ConsumerWidget {
  const EcraEditarPerfil({super.key, this.aoVoltar});

  final VoidCallback? aoVoltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabecalho = Row(
      children: [
        BotaoVoltar(aoTocar: aoVoltar),
        Expanded(
          child: Text(
            'Editar perfil',
            textAlign: TextAlign.center,
            style: estiloTexto(17, w: w800),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
    return ref
        .watch(perfilEditavelProvider)
        .when(
          loading: () => EcraBase(
            child: Column(
              children: [
                cabecalho,
                const Expanded(child: EstadoCarregar()),
              ],
            ),
          ),
          error: (erro, _) => EcraBase(
            child: Column(
              children: [
                cabecalho,
                Expanded(
                  child: EstadoErro(
                    mensagem: mensagemDe(erro),
                    aoRepetir: () => ref.invalidate(perfilEditavelProvider),
                  ),
                ),
              ],
            ),
          ),
          data: (perfil) => perfil == null
              ? EcraBase(
                  child: Column(
                    children: [
                      cabecalho,
                      const Expanded(
                        child: EstadoVazio(
                          'Ainda não tem registo de prestador. Registe-se em '
                          'Conta para ter um perfil profissional.',
                        ),
                      ),
                    ],
                  ),
                )
              : _Formulario(perfil, aoVoltar: aoVoltar),
        );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario(this.perfil, {this.aoVoltar});

  final PerfilEditavelModelo perfil;
  final VoidCallback? aoVoltar;

  @override
  ConsumerState<_Formulario> createState() => _EstadoFormulario();
}

class _EstadoFormulario extends ConsumerState<_Formulario> {
  // Preenchidos uma vez com os valores da base; depois são do utilizador.
  late final _titulo = TextEditingController(text: widget.perfil.titulo);
  late final _bio = TextEditingController(text: widget.perfil.bio);
  late final _anos = TextEditingController(
    text: widget.perfil.anosExperiencia?.toString() ?? '',
  );
  late final _telefone = TextEditingController(text: widget.perfil.telefone);

  @override
  void dispose() {
    _titulo.dispose();
    _bio.dispose();
    _anos.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final gravado = await ref
        .read(edicaoPerfilControladorProvider.notifier)
        .guardar(
          original: widget.perfil,
          titulo: _titulo.text,
          bio: _bio.text,
          anos: _anos.text,
          telefone: _telefone.text,
        );
    if (gravado && mounted) mostrarAviso(context, 'Perfil guardado.');
  }

  Future<void> _alterarFoto() async {
    const camara = 'Tirar fotografia';
    const galeria = 'Escolher da galeria';
    final opcao = await escolherOpcao(
      context,
      const [camara, galeria],
      '',
      titulo: 'Foto de perfil',
    );
    if (opcao == null) return;
    final erro = await ref
        .read(fotoPerfilControladorProvider.notifier)
        .alterar(opcao == camara ? OrigemImagem.camara : OrigemImagem.galeria);
    if (!mounted) return;
    mostrarAviso(context, erro ?? 'Foto de perfil alterada.');
  }

  @override
  Widget build(BuildContext context) {
    final perfil = widget.perfil;
    final estado = ref.watch(edicaoPerfilControladorProvider);
    final c = ref.read(edicaoPerfilControladorProvider.notifier);
    final zonasEscolhidas = estado.zonas ?? perfil.zonaIds;
    final aEnviarFoto = ref.watch(fotoPerfilControladorProvider);

    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: comEspaco([
          Row(
            children: [
              BotaoVoltar(aoTocar: widget.aoVoltar),
              Expanded(
                child: Text(
                  'Editar perfil',
                  textAlign: TextAlign.center,
                  style: estiloTexto(17, w: w800),
                ),
              ),
              GestureDetector(
                onTap: estado.aGuardar ? null : _guardar,
                child: Text(
                  estado.aGuardar ? 'A guardar…' : 'Guardar',
                  style: estiloTexto(14, w: w700, c: CoresApp.verde),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Toque(
                raio: 20,
                aoTocar: aEnviarFoto ? null : _alterarFoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FotoPrestador(
                      url: perfil.fotoUrl,
                      largura: 72,
                      altura: 72,
                      raio: 20,
                    ),
                    if (aEnviarFoto)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: CoresApp.verde,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (perfil.categoria case final c?)
                      Text(c, style: estiloTexto(14, w: w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Rosto visível aumenta a confiança',
                      style: estiloTexto(12.5, c: CoresApp.atenuado),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: aEnviarFoto ? null : _alterarFoto,
                      child: Text(
                        aEnviarFoto ? 'A enviar a foto…' : 'Alterar foto',
                        style: estiloTexto(13, w: w700, c: CoresApp.verde),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const _CartaoGaleria(),
          if (estado.erroGuardar != null) MensagemErro(estado.erroGuardar!),
          ComRotulo(
            rotulo: 'Profissão',
            dica: '(como aparece no seu perfil)',
            erro: estado.erros['titulo'],
            child: CampoTexto(
              controlador: _titulo,
              altura: 46,
              tamanhoFonte: 14,
              textoDica: perfil.categoria == null
                  ? 'Ex.: Electricista certificado'
                  : 'Ex.: ${perfil.categoria}',
              aoMudar: (_) => c.limparErro('titulo'),
            ),
          ),
          ComRotulo(
            rotulo: 'Descrição',
            erro: estado.erros['bio'],
            child: CampoTexto(
              controlador: _bio,
              altura: 46,
              alturaMinima: true,
              multilinha: true,
              tamanhoFonte: 14,
              estilo: estiloTexto(14, h: 1.4),
              textoDica: 'O que faz, como trabalha, que garantia dá.',
              aoMudar: (_) => c.limparErro('bio'),
            ),
          ),
          ComRotulo(
            rotulo: 'Experiência',
            dica: '(anos)',
            erro: estado.erros['anos'],
            child: CampoTexto(
              controlador: _anos,
              altura: 46,
              tamanhoFonte: 14,
              tipoTeclado: TextInputType.number,
              textoDica: 'Ex.: 8',
              aoMudar: (_) => c.limparErro('anos'),
            ),
          ),
          ComRotulo(
            rotulo: 'Bairros de actuação',
            erro: estado.erros['zonas'],
            child: VistaLista<ZonaModelo>(
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
                          style: estiloTexto(
                            12.5,
                            w: w700,
                            c: CoresApp.atenuado,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final z in zonasDoMunicipio(zonas, municipio))
                              Pilula(
                                z.nome,
                                seleccionado: zonasEscolhidas.contains(z.id),
                                aoTocar: () =>
                                    c.alternarZona(z.id, perfil.zonaIds),
                              ),
                          ],
                        ),
                      ],
                    ),
                ], 12),
              ),
            ),
          ),
          ComRotulo(
            rotulo: 'Telefone',
            erro: estado.erros['telefone'],
            child: CampoTexto(
              controlador: _telefone,
              altura: 46,
              tamanhoFonte: 14,
              tipoTeclado: TextInputType.phone,
              textoDica: '84 123 4567',
              prefixo: Text('+258', style: estiloTexto(14, w: w700)),
              aoMudar: (_) => c.limparErro('telefone'),
            ),
          ),
          BotaoPrimario(
            estado.aGuardar ? 'A guardar…' : 'Guardar',
            aoTocar: estado.aGuardar ? null : _guardar,
          ),
        ], 14),
      ),
    );
  }
}

/// Galeria real (em vez do "Perfil 80% completo" do design, que era
/// inventado).
class _CartaoGaleria extends ConsumerWidget {
  const _CartaoGaleria();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantas = ref.watch(meuPortfolioProvider).valueOrNull?.length;
    const limite = GaleriaControlador.limiteFotos;
    return Cartao(
      raio: 14,
      preenchimento: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      aoTocar: () => navegarPara(context, const EcraPortfolio()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Galeria de trabalhos', style: estiloTexto(13, w: w700)),
              Text(
                quantas == null ? '' : '$quantas de $limite fotografias',
                style: estiloTexto(13, c: CoresApp.atenuado),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: quantas == null ? null : quantas / limite,
              minHeight: 6,
              color: CoresApp.verde,
              backgroundColor: CoresApp.areia,
            ),
          ),
        ],
      ),
    );
  }
}
