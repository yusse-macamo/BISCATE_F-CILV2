import 'package:flutter/material.dart';

import '../../../../comum/widgets/componentes.dart';

/// Foto do prestador. Enquanto carrega, ou se não existir, mostra o
/// padrão riscado do design em vez de um espaço vazio.
class FotoPrestador extends StatelessWidget {
  const FotoPrestador({
    super.key,
    required this.url,
    this.largura,
    this.altura,
    this.raio = 14,
  });

  final String? url;
  final double? largura;
  final double? altura;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final substituto = Riscado(largura: largura, altura: altura, raio: raio);
    final endereco = url;
    if (endereco == null) return substituto;
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: SizedBox(
        width: largura,
        height: altura,
        child: Image.network(
          endereco,
          fit: BoxFit.cover,
          cacheWidth: 400,
          loadingBuilder: (_, imagem, progresso) =>
              progresso == null ? imagem : substituto,
          errorBuilder: (_, _, _) => substituto,
        ),
      ),
    );
  }
}
