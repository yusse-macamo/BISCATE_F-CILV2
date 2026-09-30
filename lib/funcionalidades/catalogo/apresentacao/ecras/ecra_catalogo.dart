import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../autenticacao/apresentacao/ecras/ecras_autenticacao.dart';
import '../../../cliente/apresentacao/ecras/ecra_avaliacao.dart';
import '../../../cliente/apresentacao/ecras/ecra_perfil_prestador.dart';
import '../../../cliente/apresentacao/ecras/ecra_principal_cliente.dart';
import '../../../cliente/apresentacao/ecras/ecra_solicitacao.dart';
import '../../../concursos/apresentacao/ecras/ecra_oportunidades.dart';
import '../../../concursos/apresentacao/ecras/ecra_prestador_escolhido.dart';
import '../../../concursos/apresentacao/ecras/ecra_propostas.dart';
import '../../../concursos/apresentacao/ecras/ecra_publicar_concurso.dart';
import '../../../concursos/apresentacao/ecras/ecra_responder_concurso.dart';
import '../../../prestador/apresentacao/ecras/ecra_assinatura.dart';
import '../../../prestador/apresentacao/ecras/ecra_portfolio.dart';
import '../../../prestador/apresentacao/ecras/ecra_principal_prestador.dart';

/// Índice de todas as telas do design, para revisão rápida.
class EcraCatalogo extends StatelessWidget {
  const EcraCatalogo({super.key});

  static final _seccoes =
      <(String, String, List<(String, String, Widget Function())>)>[
        (
          'Biscate Fácil',
          'Módulo do cliente · telas 01–09',
          [
            ('01', 'Boas-vindas', () => const EcraBoasVindas()),
            ('02', 'Login', () => const EcraEntrar()),
            ('03', 'Cadastro', () => const EcraCadastro()),
            ('04', 'Início', () => const EcraPrincipalCliente()),
            (
              '05',
              'Pesquisa e filtros',
              () => const EcraPrincipalCliente(
                separadorInicial: EcraPrincipalCliente.pesquisa,
              ),
            ),
            (
              '06',
              'Perfil do prestador',
              () => const EcraPerfilPrestador(prestadorId: ''),
            ),
            ('07', 'Solicitação', () => const EcraSolicitacao()),
            (
              '08',
              'Meus pedidos',
              () => const EcraPrincipalCliente(
                separadorInicial: EcraPrincipalCliente.pedidos,
              ),
            ),
            ('09', 'Avaliação', () => const EcraAvaliacao()),
          ],
        ),
        (
          'Prestador',
          'Módulo do prestador · telas 10–15',
          [
            ('10', 'Painel', () => const EcraPrincipalPrestador()),
            (
              '11',
              'Perfil profissional',
              () => const EcraPrincipalPrestador(
                separadorInicial: EcraPrincipalPrestador.perfil,
              ),
            ),
            ('12', 'Portfólio', () => const EcraPortfolio()),
            (
              '13',
              'Serviços e preços',
              () => const EcraPrincipalPrestador(
                separadorInicial: EcraPrincipalPrestador.servicos,
              ),
            ),
            (
              '14',
              'Gestão de pedidos',
              () => const EcraPrincipalPrestador(
                separadorInicial: EcraPrincipalPrestador.pedidos,
              ),
            ),
            ('15', 'Assinatura', () => const EcraAssinatura()),
          ],
        ),
        (
          'Concursos',
          'Nova funcionalidade · telas 16–20',
          [
            (
              '16',
              'Cliente · Publicar concurso',
              () => const EcraPublicarConcurso(),
            ),
            (
              '17',
              'Prestador · Oportunidades',
              () => const EcraOportunidades(),
            ),
            (
              '18',
              'Prestador · Responder',
              () => const EcraResponderConcurso(),
            ),
            ('19', 'Cliente · Escolher prestador', () => const EcraPropostas()),
            (
              '20',
              'Cliente · Confirmação',
              () => const EcraPrestadorEscolhido(),
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          const LinhaTitulo(
            titulo: 'Todas as telas',
            subtitulo: 'Protótipo Biscate Fácil',
          ),
          for (final (titulo, subtitulo, ecras) in _seccoes) ...[
            const SizedBox(height: 24),
            Text(titulo, style: estiloTexto(22, w: w800, ls: -0.02)),
            Text(subtitulo, style: estiloTexto(13, c: CoresApp.atenuado)),
            const SizedBox(height: 10),
            for (final (n, nome, construir) in ecras)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Cartao(
                  preenchimento: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  aoTocar: () => navegarPara(context, construir()),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text(n, style: mono(13))),
                      Expanded(
                        child: Text(nome, style: estiloTexto(14.5, w: w700)),
                      ),
                      Text('›', style: estiloTexto(18, c: CoresApp.atenuado)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
