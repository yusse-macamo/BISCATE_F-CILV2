import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../prestador/apresentacao/ecras/ecra_cadastro_prestador.dart';
import '../controladores/entrada_controlador.dart';
import '../controladores/registo_controlador.dart';
import 'ecra_encaminhamento.dart';

/// 01 · Boas-vindas
class EcraBoasVindas extends StatelessWidget {
  const EcraBoasVindas({super.key});

  @override
  Widget build(BuildContext context) {
    return EcraBase(
      fundo: CoresApp.verde,
      barraEstadoClara: true,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'BF',
                    style: estiloTexto(17, w: w800, c: CoresApp.verde),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Biscate Fácil',
                  style: estiloTexto(20, w: w800, c: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Riscado(
                raio: 24,
                banda: 8,
                a: Colors.white.withValues(alpha: .09),
                b: Colors.white.withValues(alpha: .03),
                child: Center(
                  child: Text(
                    'foto: profissional a trabalhar',
                    style: mono(12, c: Colors.white.withValues(alpha: .8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'O profissional certo, perto de si.',
              style: estiloTexto(
                32,
                w: w800,
                c: Colors.white,
                h: 1.1,
                ls: -0.02,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Prestadores verificados, preços claros e avaliações reais em Maputo e Matola.',
              style: estiloTexto(15, c: CoresApp.sobreVerdeSuave, h: 1.5),
            ),
            const SizedBox(height: 28),
            BotaoPrimario(
              'Criar conta',
              fundo: Colors.white,
              frente: CoresApp.verde,
              aoTocar: () => navegarPara(context, const EcraCadastro()),
            ),
            const SizedBox(height: 12),
            BotaoContorno(
              'Entrar',
              cor: Colors.white,
              corBorda: Colors.white.withValues(alpha: .55),
              larguraBorda: 1.5,
              aoTocar: () => navegarPara(context, const EcraEntrar()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 02 · Entrar
///
/// Só e-mail e palavra-passe: a autenticação é por e-mail, e o telefone é um
/// campo do perfil, não uma forma de entrar.
class EcraEntrar extends ConsumerStatefulWidget {
  const EcraEntrar({super.key});

  @override
  ConsumerState<EcraEntrar> createState() => _EstadoEcraEntrar();
}

class _EstadoEcraEntrar extends ConsumerState<EcraEntrar> {
  final _email = TextEditingController();
  final _palavraPasse = TextEditingController();
  bool _mostrar = false;

  @override
  void dispose() {
    _email.dispose();
    _palavraPasse.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final entrou = await ref
        .read(entradaControladorProvider.notifier)
        .entrar(email: _email.text, palavraPasse: _palavraPasse.text);
    if (entrou && mounted) reiniciarCom(context, const EcraEncaminhamento());
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(entradaControladorProvider);
    final controlador = ref.read(entradaControladorProvider.notifier);
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        espaco: 22,
        children: [
          const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bem-vindo de volta',
                style: estiloTexto(28, w: w800, ls: -0.02),
              ),
              const SizedBox(height: 6),
              Text(
                'Entre para ver os seus pedidos.',
                style: estiloTexto(15, c: CoresApp.atenuado),
              ),
            ],
          ),
          ComRotulo(
            rotulo: 'E-mail',
            espaco: 8,
            erro: estado.erros['email'],
            child: CampoTexto(
              controlador: _email,
              altura: 52,
              tamanhoFonte: 16,
              tipoTeclado: TextInputType.emailAddress,
              textoDica: 'o.seu@email.com',
              aoMudar: (_) => controlador.limparErro('email'),
            ),
          ),
          // TODO: "Recuperar senha" volta quando houver resetPasswordForEmail e
          // o ecrã para definir a nova palavra-passe a partir do link.
          ComRotulo(
            rotulo: 'Palavra-passe',
            espaco: 8,
            erro: estado.erros['palavraPasse'],
            child: CampoTexto(
              controlador: _palavraPasse,
              altura: 52,
              tamanhoFonte: 16,
              ocultar: !_mostrar,
              aoMudar: (_) => controlador.limparErro('palavraPasse'),
              sufixo: GestureDetector(
                onTap: () => setState(() => _mostrar = !_mostrar),
                child: Text(
                  _mostrar ? 'Ocultar' : 'Mostrar',
                  style: estiloTexto(13, w: w600, c: CoresApp.atenuado),
                ),
              ),
            ),
          ),
          if (estado.erroGeral != null) MensagemErro(estado.erroGeral!),
          const Spacer(),
          BotaoPrimario(
            estado.aEnviar ? 'A entrar…' : 'Entrar',
            aoTocar: estado.aEnviar ? null : _entrar,
          ),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const EcraCadastro()),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Não tem conta? ',
                      style: estiloTexto(14, c: CoresApp.atenuado),
                    ),
                    TextSpan(
                      text: 'Criar conta',
                      style: estiloTexto(14, w: w700, c: CoresApp.verde),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 03 · Cadastro
///
/// Com [comoPrestador], depois de criar a conta segue para o cadastro do
/// prestador (que precisa de sessão).
class EcraCadastro extends ConsumerStatefulWidget {
  const EcraCadastro({super.key, this.comoPrestador = false});

  final bool comoPrestador;

  @override
  ConsumerState<EcraCadastro> createState() => _EstadoEcraCadastro();
}

class _EstadoEcraCadastro extends ConsumerState<EcraCadastro> {
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _palavraPasse = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _palavraPasse.dispose();
    super.dispose();
  }

  Future<void> _registar() async {
    final resultado = await ref
        .read(registoControladorProvider.notifier)
        .registar(
          nome: _nome.text,
          telefone: _telefone.text,
          email: _email.text,
          palavraPasse: _palavraPasse.text,
        );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoRegisto.comSessao:
        final navegador = Navigator.of(context);
        reiniciarCom(context, const EcraEncaminhamento());
        if (widget.comoPrestador) {
          navegador.push(
            MaterialPageRoute(builder: (_) => const EcraCadastroPrestador()),
          );
        }
      case ResultadoRegisto.confirmarEmail:
        mostrarAviso(
          context,
          widget.comoPrestador
              ? 'Conta criada. Abra o link que enviámos para o seu e-mail, '
                    'entre, e registe os seus serviços em Conta.'
              : 'Conta criada. Abra o link que enviámos para o seu e-mail e depois entre.',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EcraEntrar()),
        );
      case ResultadoRegisto.falhou:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(registoControladorProvider);
    final controlador = ref.read(registoControladorProvider.notifier);
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BotaoVoltar(),
              Text(
                widget.comoPrestador ? 'Prestador' : 'Cliente',
                style: estiloTexto(13, w: w600, c: CoresApp.atenuado),
              ),
            ],
          ),
          Text('Criar conta', style: estiloTexto(26, w: w800, ls: -0.02)),
          ComRotulo(
            rotulo: 'Nome completo',
            erro: estado.erros['nome'],
            child: CampoTexto(
              controlador: _nome,
              textoDica: 'Ex.: Ana Sitoe',
              aoMudar: (_) => controlador.limparErro('nome'),
            ),
          ),
          ComRotulo(
            rotulo: 'Telefone',
            erro: estado.erros['telefone'],
            child: CampoTexto(
              controlador: _telefone,
              tipoTeclado: TextInputType.phone,
              textoDica: '84 123 4567',
              aoMudar: (_) => controlador.limparErro('telefone'),
            ),
          ),
          ComRotulo(
            rotulo: 'E-mail',
            erro: estado.erros['email'],
            child: CampoTexto(
              controlador: _email,
              tipoTeclado: TextInputType.emailAddress,
              textoDica: 'o.seu@email.com',
              aoMudar: (_) => controlador.limparErro('email'),
            ),
          ),
          ComRotulo(
            rotulo: 'Palavra-passe',
            erro: estado.erros['palavraPasse'],
            child: CampoTexto(
              controlador: _palavraPasse,
              ocultar: true,
              textoDica: 'Pelo menos 6 caracteres',
              aoMudar: (_) => controlador.limparErro('palavraPasse'),
            ),
          ),
          _SeleccaoZona(estado: estado, controlador: controlador),
          if (estado.erroGeral != null) MensagemErro(estado.erroGeral!),
          const Spacer(),
          BotaoPrimario(
            estado.aEnviar ? 'A criar conta…' : 'Criar conta',
            aoTocar: estado.aEnviar ? null : _registar,
          ),
          if (!widget.comoPrestador)
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const EcraCadastro(comoPrestador: true),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'É prestador? ',
                        style: estiloTexto(14, c: CoresApp.atenuado),
                      ),
                      TextSpan(
                        text: 'Registe os seus serviços',
                        style: estiloTexto(14, w: w700, c: CoresApp.verde),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Município e bairro, lidos de `zonas`. Guarda o `id` da zona e só mostra os
/// bairros do município escolhido.
class _SeleccaoZona extends ConsumerWidget {
  const _SeleccaoZona({required this.estado, required this.controlador});

  final EstadoRegisto estado;
  final RegistoControlador controlador;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(zonasProvider)
        .when(
          loading: () => _grelha(
            municipio: const CaixaSeleccao(
              valor: 'A carregar…',
              opcoes: [],
              aoMudar: _ignorar,
              activa: false,
            ),
            bairro: const CaixaSeleccao(
              valor: 'A carregar…',
              opcoes: [],
              aoMudar: _ignorar,
              activa: false,
            ),
          ),
          error: (erro, _) => _erro(ref, mensagemDe(erro)),
          data: (zonas) {
            if (zonas.isEmpty) {
              return _erro(ref, 'Ainda não há bairros disponíveis.');
            }
            final bairros = zonasDoMunicipio(zonas, estado.municipio);
            final escolhida = bairros
                .where((zona) => zona.id == estado.zonaId)
                .firstOrNull;
            return _grelha(
              municipio: CaixaSeleccao(
                titulo: 'Município',
                valor: estado.municipio ?? 'Escolher',
                opcoes: municipiosDe(zonas),
                aoMudar: controlador.escolherMunicipio,
              ),
              bairro: CaixaSeleccao(
                titulo: 'Bairro',
                valor: escolhida?.nome ?? 'Escolher',
                opcoes: [for (final zona in bairros) zona.nome],
                activa: estado.municipio != null,
                aoMudar: (nome) => controlador.escolherZona(
                  bairros.firstWhere((zona) => zona.nome == nome).id,
                ),
              ),
            );
          },
        );
  }

  static void _ignorar(String _) {}

  Widget _grelha({required Widget municipio, required Widget bairro}) =>
      GrelhaUniforme(
        colunas: 2,
        children: [
          ComRotulo(
            rotulo: 'Município',
            erro: estado.erros['municipio'],
            child: municipio,
          ),
          ComRotulo(
            rotulo: 'Bairro',
            erro: estado.erros['zona'],
            child: bairro,
          ),
        ],
      );

  Widget _erro(WidgetRef ref, String mensagem) => ComRotulo(
    rotulo: 'Município e bairro',
    child: EstadoErro(
      mensagem: mensagem,
      aoRepetir: () => ref.invalidate(zonasProvider),
    ),
  );
}
