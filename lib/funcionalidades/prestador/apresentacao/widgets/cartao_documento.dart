import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';
import '../../../../nucleo/tema/tema_app.dart';
import '../../../../nucleo/utilitarios/imagens.dart';

/// Um documento a enviar: vazio, mostra "+ Escolher"; escolhido, mostra a
/// miniatura, o nome do ficheiro e as acções de trocar e remover.
class CartaoDocumento extends StatelessWidget {
  const CartaoDocumento({
    super.key,
    required this.titulo,
    required this.apoio,
    required this.imagem,
    required this.aoEscolher,
    required this.aoRemover,
    this.activo = true,
  });

  static const _lado = 56.0;

  final String titulo;
  final String apoio;
  final ImagemEscolhida? imagem;
  final VoidCallback aoEscolher;
  final VoidCallback aoRemover;

  /// Falso durante o envio: não se troca um documento que está a subir.
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final escolhida = imagem;
    return Cartao(
      corBorda: escolhida == null ? CoresApp.borda : CoresApp.verde,
      larguraBorda: escolhida == null ? 1 : 1.5,
      aoTocar: activo && escolhida == null ? aoEscolher : null,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: _lado,
              child: escolhida == null
                  ? const Riscado(raio: 0)
                  : Image.memory(
                      escolhida.bytes,
                      fit: BoxFit.cover,
                      // Descodifica a miniatura pequena, não a foto de 12 MP.
                      cacheWidth: 168,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: estiloTexto(15, w: w800)),
                const SizedBox(height: 2),
                Text(
                  escolhida?.nome ?? apoio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: escolhida == null
                      ? estiloTexto(12.5, c: CoresApp.atenuado)
                      : mono(11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (escolhida == null)
            Text(
              '+ Escolher',
              style: estiloTexto(13, w: w700, c: CoresApp.verde),
            )
          else if (activo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: aoEscolher,
                  child: Text(
                    'Trocar',
                    style: estiloTexto(13, w: w700, c: CoresApp.verde),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: aoRemover,
                  child: Text(
                    'Remover',
                    style: estiloTexto(13, w: w700, c: CoresApp.rejeitar),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
