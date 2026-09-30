import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../cliente/apresentacao/ecras/ecra_principal_cliente.dart';

/// 20 · Cliente · Confirmação
class EcraPrestadorEscolhido extends StatelessWidget {
  const EcraPrestadorEscolhido({
    super.key,
    this.nome = 'Fernando Chissano',
    this.servico = 'Canos da casa de banho',
    this.preco = '1 800 MT',
  });

  final String nome;
  final String servico;
  final String preco;

  @override
  Widget build(BuildContext context) {
    return EcraBase(
      child: ScrollPreenchido(
        preenchimento: const EdgeInsets.fromLTRB(24, 40, 24, 20),
        espaco: 20,
        children: [
          Column(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CoresApp.verde,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '✓',
                  style: estiloTexto(32, w: w800, c: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Escolheu $nome',
                textAlign: TextAlign.center,
                style: estiloTexto(24, w: w800, ls: -0.01),
              ),
              const SizedBox(height: 12),
              Text(
                'O prestador foi notificado e vai confirmar a hora. Os outros prestadores são informados de que o concurso fechou.',
                textAlign: TextAlign.center,
                style: estiloTexto(14, c: CoresApp.atenuado, h: 1.5),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CoresApp.borda),
            ),
            child: Column(
              children: [
                LinhaChaveValor(
                  rotulo: 'Serviço',
                  valor: Text(
                    servico,
                    style: estiloTexto(14, w: w700),
                    textAlign: TextAlign.right,
                  ),
                ),
                LinhaChaveValor(
                  rotulo: 'Valor acordado',
                  valor: Text(preco, style: estiloTexto(14, w: w700)),
                ),
                const LinhaChaveValor(
                  ultimo: true,
                  rotulo: 'Estado',
                  valor: Selo(
                    'Aceite',
                    fundo: CoresApp.verdeClaro,
                    frente: CoresApp.verdeEscuro,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GrelhaUniforme(
            colunas: 2,
            children: [
              BotaoContorno(
                'Ligar',
                altura: 52,
                tamanhoFonte: 15,
                aoTocar: () => mostrarAviso(context, 'A ligar para $nome…'),
              ),
              BotaoContorno(
                'WhatsApp',
                altura: 52,
                tamanhoFonte: 15,
                aoTocar: () => mostrarAviso(context, 'A abrir WhatsApp…'),
              ),
            ],
          ),
          BotaoPrimario(
            'Ver em Meus pedidos',
            aoTocar: () => reiniciarCom(
              context,
              const EcraPrincipalCliente(
                separadorInicial: EcraPrincipalCliente.pedidos,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
