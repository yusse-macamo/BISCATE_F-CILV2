import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/navegacao/navegacao.dart';
import '../../../../nucleo/tema/tema_app.dart';
import 'ecra_portfolio.dart';

/// 11 · Perfil profissional
class EcraEditarPerfil extends StatelessWidget {
  const EcraEditarPerfil({super.key, this.aoVoltar});

  final VoidCallback? aoVoltar;

  static const _campos = [
    ('Profissão', 'Electricista'),
    (
      'Descrição',
      'Instalações e reparações eléctricas residenciais e comerciais. Garantia de 30 dias.',
    ),
    ('Experiência', '8 anos'),
    ('Bairro de actuação', 'Matola · Fomento, Machava, Liberdade'),
    ('Contactos', '+258 84 555 0192 · WhatsApp'),
  ];

  @override
  Widget build(BuildContext context) {
    return EcraBase(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: comEspaco([
          Row(
            children: [
              BotaoVoltar(aoTocar: aoVoltar),
              Expanded(
                child: Text(
                  'Editar perfil',
                  textAlign: TextAlign.center,
                  style: estiloTexto(17, w: w800),
                ),
              ),
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  mostrarAviso(context, 'Perfil guardado.');
                },
                child: Text(
                  'Guardar',
                  style: estiloTexto(14, w: w700, c: CoresApp.verde),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Riscado(
                largura: 72,
                altura: 72,
                raio: 20,
                a: CoresApp.avatarA,
                b: CoresApp.avatarB,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => mostrarAviso(
                      context,
                      'Escolher fotografia — em breve.',
                    ),
                    child: Text(
                      'Alterar fotografia',
                      style: estiloTexto(14, w: w700, c: CoresApp.verde),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rosto visível aumenta a confiança',
                    style: estiloTexto(12.5, c: CoresApp.atenuado),
                  ),
                ],
              ),
            ],
          ),
          Cartao(
            raio: 14,
            preenchimento: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            aoTocar: () => navegarPara(context, const EcraPortfolio()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Perfil 80% completo',
                      style: estiloTexto(13, w: w700),
                    ),
                    Text(
                      'Falta: 2 fotos',
                      style: estiloTexto(13, c: CoresApp.atenuado),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(
                    value: .8,
                    minHeight: 6,
                    color: CoresApp.verde,
                    backgroundColor: CoresApp.areia,
                  ),
                ),
              ],
            ),
          ),
          for (final (rotulo, valor) in _campos)
            ComRotulo(
              rotulo: rotulo,
              child: CampoTexto(
                valorInicial: valor,
                altura: 46,
                alturaMinima: true,
                multilinha: rotulo == 'Descrição',
                tamanhoFonte: 14,
                estilo: estiloTexto(14, h: 1.4),
              ),
            ),
        ], 14),
      ),
    );
  }
}
