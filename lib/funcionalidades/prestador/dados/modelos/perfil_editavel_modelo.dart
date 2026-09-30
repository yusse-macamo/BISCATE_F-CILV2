/// O que o prestador edita no ecrã "Editar perfil": `prestadores.titulo`,
/// `bio`, `anos_experiencia`, as zonas (`prestador_zonas`) e o telefone
/// (`perfis.telefone`). A categoria só se mostra.
class PerfilEditavelModelo {
  const PerfilEditavelModelo({
    required this.titulo,
    required this.bio,
    required this.anosExperiencia,
    required this.zonaIds,
    required this.telefone,
    this.categoria,
    this.fotoUrl,
  });

  final String titulo;
  final String bio;
  final int? anosExperiencia;
  final Set<String> zonaIds;
  final String telefone;
  final String? categoria;
  final String? fotoUrl;
}
