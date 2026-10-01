import '../../../../nucleo/dados/leitura_json.dart';

/// Um preço como o cliente o vê: serviço do catálogo ou próprio. `valor` nulo
/// é "sob orçamento".
class PrecoPublicoModelo {
  const PrecoPublicoModelo({required this.servico, this.valor, this.servicoId});

  final String servico;
  final int? valor;

  /// `id` do serviço do catálogo; nulo nos serviços próprios, que não podem
  /// ser pedidos directamente (`pedidos.servico_id` aponta para `servicos`).
  final String? servicoId;
}

/// Um prestador como aparece na procura, nos destaques e no perfil:
/// `prestadores` com `perfis`, categoria, zonas e preços.
///
/// As estatísticas vêm já calculadas da base; a app só as mostra.
class PrestadorPublicoModelo {
  const PrestadorPublicoModelo({
    required this.perfilId,
    required this.nome,
    required this.fotoUrl,
    this.titulo,
    this.categoriaId,
    this.categoria,
    this.zonas = const [],
    this.verificado = false,
    this.avaliacaoMedia,
    this.totalAvaliacoes = 0,
    this.servicosFeitos = 0,
    this.pctRecomenda,
    this.bio,
    this.anosExperiencia,
    this.precos = const [],
  });

  /// [fotoUrl] vem já resolvida pelo repositório.
  factory PrestadorPublicoModelo.fromJson(
    Map<String, dynamic> json, {
    required String? fotoUrl,
  }) {
    final perfil = lerObjecto(json['perfis']);
    final categoria = lerObjecto(json['categorias']);

    return PrestadorPublicoModelo(
      perfilId: '${json['perfil_id']}',
      nome: lerTexto(perfil?['nome']) ?? '',
      fotoUrl: fotoUrl,
      titulo: json['titulo'] as String?,
      categoriaId: json['categoria_id'] == null
          ? null
          : '${json['categoria_id']}',
      categoria: lerTexto(categoria?['nome']),
      zonas: [
        for (final linha in lerLista(json['prestador_zonas']))
          ?lerTexto(lerObjecto(linha['zonas'])?['nome']),
      ],
      verificado: json['verificado'] as bool? ?? false,
      avaliacaoMedia: (json['avaliacao_media'] as num?)?.toDouble(),
      totalAvaliacoes: (json['total_avaliacoes'] as num?)?.toInt() ?? 0,
      servicosFeitos: (json['servicos_feitos'] as num?)?.toInt() ?? 0,
      pctRecomenda: (json['pct_recomenda'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      anosExperiencia: (json['anos_experiencia'] as num?)?.toInt(),
      precos: [
        for (final linha in lerLista(json['precos_prestador']))
          if (lerTexto(lerObjecto(linha['servicos'])?['nome']) case final nome?)
            PrecoPublicoModelo(
              servico: nome,
              valor: lerInteiro(linha['valor']),
              servicoId: '${linha['servico_id']}',
            ),
        for (final linha in lerLista(json['servicos_proprios']))
          if (lerTexto(linha['nome']) case final nome?)
            PrecoPublicoModelo(
              servico: nome,
              valor: lerInteiro(linha['valor']),
            ),
      ],
    );
  }

  final String perfilId;
  final String nome;
  final String? fotoUrl;
  final String? titulo;
  final String? categoriaId;
  final String? categoria;

  /// Nomes das zonas onde atende.
  final List<String> zonas;
  final bool verificado;

  /// Nula enquanto não houver avaliações.
  final double? avaliacaoMedia;
  final int totalAvaliacoes;
  final int servicosFeitos;

  /// Percentagem (0–100) que recomenda. Nula sem avaliações.
  final double? pctRecomenda;
  final String? bio;
  final int? anosExperiencia;
  final List<PrecoPublicoModelo> precos;

  /// Título, se o prestador tiver um; senão, a categoria.
  String? get descricao =>
      (titulo?.trim().isNotEmpty ?? false) ? titulo : categoria;

  /// O preço mais baixo indicado, para "desde X MT". Só serve para mostrar;
  /// a lista nunca é ordenada por preço.
  int? get desde {
    final valores = [for (final p in precos) ?p.valor];
    if (valores.isEmpty) return null;
    return valores.reduce((a, b) => a < b ? a : b);
  }
}
