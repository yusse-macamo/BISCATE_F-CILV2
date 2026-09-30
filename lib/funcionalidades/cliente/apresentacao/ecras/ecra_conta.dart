import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/apresentacao/ecras/ecra_encaminhamento.dart';
import '../../../catalogo/apresentacao/ecras/ecra_catalogo.dart';
import '../../../concursos/apresentacao/ecras/ecra_publicar_concurso.dart';
import '../../../prestador/apresentacao/ecras/ecra_cadastro_prestador.dart';
import '../../dados/repositorios/perfil_cliente_repositorio.dart';
import '../controladores/perfil_cliente_controlador.dart';

/// Separador "Conta". Não existe no design; serve de ponto de entrada para
/// os concursos, o modo prestador e o catálogo de telas.
class EcraConta extends ConsumerWidget {
  const EcraConta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: comEspaco([
          Text('Conta', style: estiloTexto(26, w: w800, ls: -0.02)),
          ref
              .watch(perfilClienteProvider)
              .when(
                loading: () => const Cartao(child: EstadoCarregar()),
                error: (erro, _) => Cartao(
                  child: EstadoErro(
                    mensagem: mensagemDe(erro),
                    aoRepetir: () => ref.invalidate(perfilClienteProvider),
                  ),
                ),
                data: (perfil) => perfil == null
                    ? const Cartao(
                        child: EstadoVazio(
                          'Não foi possível ler o seu perfil.',
                        ),
                      )
                    : _CartaoPerfil(perfil),
              ),
          _LinhaConta(
            'Publicar concurso',
            'Receba propostas de vários prestadores',
            () => navegarPara(context, const EcraPublicarConcurso()),
          ),
          _LinhaConta(
            'Registar-me como prestador',
            'Receba pedidos na sua zona',
            () => navegarPara(context, const EcraCadastroPrestador()),
          ),
          _LinhaConta(
            'Todas as telas',
            'Catálogo do protótipo (01–20)',
            () => navegarPara(context, const EcraCatalogo()),
          ),
          _LinhaConta('Terminar sessão', null, () async {
            final erro = await ref
                .read(sessaoControladorProvider)
                .terminarSessao();
            if (!context.mounted) return;
            if (erro != null) return mostrarAviso(context, erro);
            reiniciarCom(context, const EcraEncaminhamento());
          }, perigo: true),
        ], 10),
      ),
    );
  }
}

class _LinhaConta extends StatelessWidget {
  const _LinhaConta(
    this.titulo,
    this.subtitulo,
    this.aoTocar, {
    this.perigo = false,
  });

  final String titulo;
  final String? subtitulo;
  final VoidCallback aoTocar;
  final bool perigo;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      aoTocar: aoTocar,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: estiloTexto(
                    15,
                    w: w800,
                    c: perigo ? CoresApp.rejeitar : CoresApp.tinta,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: estiloTexto(12.5, c: CoresApp.atenuado),
                  ),
              ],
            ),
          ),
          Text('›', style: estiloTexto(20, c: CoresApp.atenuado)),
        ],
      ),
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  const _CartaoPerfil(this.perfil);

  final PerfilClienteModelo perfil;

  @override
  Widget build(BuildContext context) {
    final detalhe = [
      if (perfil.telefone case final t? when t.isNotEmpty) '+258 $t',
      ?perfil.zona,
    ].join(' · ');
    return Cartao(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CoresApp.verde,
              shape: BoxShape.circle,
            ),
            child: Text(
              perfil.inicial,
              style: estiloTexto(20, w: w800, c: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perfil.nome, style: estiloTexto(16, w: w800)),
                if (detalhe.isNotEmpty)
                  Text(detalhe, style: estiloTexto(12.5, c: CoresApp.atenuado)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
