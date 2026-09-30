/// O prestador autenticado, como o painel o mostra: `prestadores` com o
/// `perfis` associado, a categoria e as zonas.
///
/// As estatísticas vêm já calculadas da base (actualizadas por gatilho); a
/// app só as mostra, nunca as calcula.
class PainelPrestadorModelo {
  const PainelPrestadorModelo({
    required this.perfilId,
    required this.nome,
    required this.fotoUrl,
    required this.titulo,
    required this.categoria,
    required this.zonas,
    required this.verificado,
    required this.avaliacaoMedia,
    required this.totalAvaliacoes,
    required this.servicosFeitos,
    required this.pctRecomenda,
  });

  /// [fotoUrl] vem já resolvida pelo repositório (ver
  /// `PrestadorRepositorio.obterPainel`).
  factory PainelPrestadorModelo.fromJson(
    Map<String, dynamic> json, {
    required String? fotoUrl,
  }) {
    final perfil = json['perfis'] as Map<String, dynamic>?;
    final categoria = json['categorias'] as Map<String, dynamic>?;
    final zonas = (json['prestador_zonas'] as List<dynamic>? ?? const [])
        .map((linha) => (linha as Map<String, dynamic>)['zonas'])
        .whereType<Map<String, dynamic>>()
        .map((zona) => zona['nome'] as String)
        .toList();
    return PainelPrestadorModelo(
      perfilId: '${json['perfil_id']}',
      nome: perfil?['nome'] as String? ?? '',
      fotoUrl: fotoUrl,
      titulo: json['titulo'] as String?,
      categoria: categoria?['nome'] as String?,
      zonas: zonas,
      verificado: json['verificado'] as bool? ?? false,
      avaliacaoMedia: (json['avaliacao_media'] as num?)?.toDouble(),
      totalAvaliacoes: (json['total_avaliacoes'] as num?)?.toInt() ?? 0,
      servicosFeitos: (json['servicos_feitos'] as num?)?.toInt() ?? 0,
      pctRecomenda: (json['pct_recomenda'] as num?)?.toDouble(),
    );
  }

  final String perfilId;
  final String nome;
  final String? fotoUrl;
  final String? titulo;
  final String? categoria;

  /// Nomes das zonas onde atende.
  final List<String> zonas;
  final bool verificado;

  /// Nula enquanto não houver avaliações.
  final double? avaliacaoMedia;
  final int totalAvaliacoes;
  final int servicosFeitos;

  /// Percentagem (0–100) de avaliações que recomendam. Nula sem avaliações.
  final double? pctRecomenda;

  /// O que aparece por baixo do nome: o título, se o prestador tiver um;
  /// senão, a categoria.
  String? get descricao =>
      (titulo?.trim().isNotEmpty ?? false) ? titulo : categoria;
}
