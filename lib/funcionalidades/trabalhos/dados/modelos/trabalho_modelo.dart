import '../../../pedidos/dados/modelos/pedido_modelo.dart';

/// Um trabalho (`trabalhos`), criado pelo servidor quando o prestador aceita
/// um pedido (`aceitar_pedido`) ou quando o cliente escolhe uma proposta
/// (`adjudicar_concurso`). A app nunca o cria.
class TrabalhoModelo {
  const TrabalhoModelo({
    required this.id,
    required this.estado,
    required this.prestadorId,
    required this.servico,
    this.valorAcordado,
    this.prestadorNome,
    this.origemConcurso = false,
    this.criadoEm,
    this.concluidoEm,
    this.avaliado = false,
    this.descricao,
    this.zona,
    this.endereco,
    this.cliente,
  });

  factory TrabalhoModelo.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? objecto(Object? v) => switch (v) {
      final Map<String, dynamic> m => m,
      [final Map<String, dynamic> m, ...] => m,
      _ => null,
    };
    final prestador = objecto(json['prestador']);
    final concurso = objecto(json['concursos']);
    final cliente = objecto(json['cliente']);
    return TrabalhoModelo(
      id: '${json['id']}',
      estado: json['estado'] as String? ?? '',
      prestadorId: '${json['prestador_id']}',
      servico:
          objecto(json['servicos'])?['nome'] as String? ??
          concurso?['titulo'] as String? ??
          'Serviço',
      valorAcordado: (json['valor_acordado'] as num?)?.toInt(),
      prestadorNome: objecto(prestador?['perfis'])?['nome'] as String?,
      origemConcurso: json['concurso_id'] != null,
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      concluidoEm: DateTime.tryParse('${json['concluido_em']}')?.toLocal(),
      // Uma avaliação por trabalho; a lista embebida diz se já existe.
      avaliado: (json['avaliacoes'] as List<dynamic>?)?.isNotEmpty ?? false,
      descricao: concurso?['descricao'] as String?,
      zona: objecto(concurso?['zonas'])?['nome'] as String?,
      endereco: concurso?['endereco'] as String?,
      // Com o trabalho criado, a RLS deixa o prestador ler o perfil do
      // cliente. Se ainda assim vier nulo, o ecrã diz que não está
      // disponível; não é erro.
      cliente: cliente == null
          ? null
          : ContactoClienteModelo(
              nome: cliente['nome'] as String? ?? '',
              telefone: cliente['telefone'] as String?,
            ),
    );
  }

  final String id;

  /// `estado_trabalho` da base (`agendado`, …, `concluido`, `cancelado`).
  final String estado;
  final String prestadorId;
  final String servico;
  final int? valorAcordado;
  final String? prestadorNome;
  final bool origemConcurso;
  final DateTime? criadoEm;
  final DateTime? concluidoEm;
  final bool avaliado;

  // Para o prestador (trabalhos vindos de concursos).
  final String? descricao;
  final String? zona;
  final String? endereco;
  final ContactoClienteModelo? cliente;

  bool get concluido => estado == 'concluido';
  bool get cancelado => estado == 'cancelado';
  bool get emCurso => !concluido && !cancelado;
}

/// O que se envia para `avaliacoes`: só `trabalho_id`, `estrelas`,
/// `comentario` e `recomenda`. A base só aceita se o trabalho estiver
/// concluído e for de quem avalia; a média e a percentagem de recomendação
/// do prestador actualizam-se por gatilho.
class NovaAvaliacaoModelo {
  const NovaAvaliacaoModelo({
    required this.trabalhoId,
    required this.estrelas,
    required this.recomenda,
    this.comentario,
  });

  final String trabalhoId;
  final int estrelas;
  final bool recomenda;
  final String? comentario;

  Map<String, dynamic> toJson() => {
    'trabalho_id': trabalhoId,
    'estrelas': estrelas,
    'comentario': comentario,
    'recomenda': recomenda,
  };
}
