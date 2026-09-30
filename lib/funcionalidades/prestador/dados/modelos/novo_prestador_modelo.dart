/// O que a app envia para `prestadores` ao registar um prestador.
///
/// Só entram as colunas que a app pode escrever: `perfil_id`,
/// `categoria_id`, `titulo`, `bio`, `anos_experiencia`, `capa` e `raio_km`.
/// `estado` (fica `pendente` pelo valor por omissão), `verificado`,
/// `aprovado_em` e as estatísticas são do servidor e do administrador, e por
/// isso nem existem aqui. A foto de perfil não vai para `prestadores`: vai
/// para `perfis.foto`.
class NovoPrestadorModelo {
  const NovoPrestadorModelo({
    required this.perfilId,
    required this.categoriaId,
    this.titulo,
    this.bio,
    this.anosExperiencia,
    this.capa,
    this.raioKm,
  });

  /// `auth.uid()` de quem se regista.
  final String perfilId;
  final String categoriaId;
  final String? titulo;
  final String? bio;
  final int? anosExperiencia;

  /// Caminho da imagem de capa no bucket `publico`.
  final String? capa;
  final int? raioKm;

  /// Os campos opcionais vazios não são enviados, para valerem os valores por
  /// omissão da tabela (um `null` explícito sobrepunha-se a eles).
  Map<String, dynamic> toJson() => {
    'perfil_id': perfilId,
    'categoria_id': categoriaId,
    'titulo': ?titulo,
    'bio': ?bio,
    'anos_experiencia': ?anosExperiencia,
    'capa': ?capa,
    'raio_km': ?raioKm,
  };
}
