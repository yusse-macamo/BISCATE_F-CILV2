/// Linha de `precos_prestador`: o valor que um prestador pede por um serviço
/// do catálogo. `valor` nulo é válido e significa "sob orçamento".
class PrecoPrestadorModelo {
  const PrecoPrestadorModelo({required this.servicoId, this.valor});

  factory PrecoPrestadorModelo.fromJson(Map<String, dynamic> json) =>
      PrecoPrestadorModelo(
        servicoId: '${json['servico_id']}',
        valor: (json['valor'] as num?)?.toInt(),
      );

  final String servicoId;
  final int? valor;

  Map<String, dynamic> toJson(String prestadorId) => {
    'prestador_id': prestadorId,
    'servico_id': servicoId,
    'valor': valor,
  };
}

/// Linha de `servicos_proprios`: serviço fora do catálogo, com nome livre.
/// O servidor limita a 3 por prestador (gatilho).
class ServicoProprioModelo {
  const ServicoProprioModelo({
    required this.id,
    required this.nome,
    this.valor,
  });

  factory ServicoProprioModelo.fromJson(Map<String, dynamic> json) =>
      ServicoProprioModelo(
        id: '${json['id']}',
        nome: json['nome'] as String,
        valor: (json['valor'] as num?)?.toInt(),
      );

  final String id;
  final String nome;

  /// Nulo significa "sob orçamento".
  final int? valor;

  Map<String, dynamic> toJson(String prestadorId) => {
    'prestador_id': prestadorId,
    'nome': nome,
    'valor': valor,
  };
}
