/// Linha de `servicos`. Cada serviço pertence a uma categoria.
class ServicoModelo {
  const ServicoModelo({
    required this.id,
    required this.nome,
    required this.categoriaId,
  });

  factory ServicoModelo.fromJson(Map<String, dynamic> json) => ServicoModelo(
    id: '${json['id']}',
    nome: json['nome'] as String,
    categoriaId: '${json['categoria_id']}',
  );

  final String id;
  final String nome;
  final String categoriaId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'categoria_id': categoriaId,
  };
}
