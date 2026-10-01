import '../../../../nucleo/dados/leitura_json.dart';

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
    final perfil = lerObjecto(json['perfis']);
    final categoria = lerObjecto(json['categorias']);
    final zonas = [
      for (final linha in lerLista(json['prestador_zonas']))
        ?lerTexto(lerObjecto(linha['zonas'])?['nome']),
    ];
    return PainelPrestadorModelo(
      perfilId: '${json['perfil_id']}',
      nome: lerTexto(perfil?['nome']) ?? '',
      fotoUrl: fotoUrl,
      titulo: json['titulo'] as String?,
      categoria: lerTexto(categoria?['nome']),
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
