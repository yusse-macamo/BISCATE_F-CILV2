/// Linha de `zonas`. O `id` é o que se guarda ('fomento'); o `nome` é só para
/// mostrar ('Fomento').
class ZonaModelo {
  const ZonaModelo({
    required this.id,
    required this.nome,
    required this.municipio,
  });

  factory ZonaModelo.fromJson(Map<String, dynamic> json) => ZonaModelo(
    id: json['id'] as String,
    nome: json['nome'] as String,
    municipio: json['municipio'] as String,
  );

  final String id;
  final String nome;
  final String municipio;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'municipio': municipio,
  };
}
