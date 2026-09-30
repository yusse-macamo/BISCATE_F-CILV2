/// Linha de `categorias`.
class CategoriaModelo {
  const CategoriaModelo({
    required this.id,
    required this.nome,
    this.icone,
    this.descricao,
  });

  factory CategoriaModelo.fromJson(Map<String, dynamic> json) =>
      CategoriaModelo(
        id: '${json['id']}',
        nome: json['nome'] as String,
        icone: json['icone'] as String?,
        descricao: json['descricao'] as String?,
      );

  final String id;
  final String nome;
  final String? icone;
  final String? descricao;

  /// Duas letras para a célula da grelha do início ('Canalização' → 'Ca').
  /// A tabela não tem abreviatura; deriva-se do nome, como no design.
  String get abreviatura => nome.length <= 2 ? nome : nome.substring(0, 2);

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'icone': icone,
    'descricao': descricao,
  };
}
