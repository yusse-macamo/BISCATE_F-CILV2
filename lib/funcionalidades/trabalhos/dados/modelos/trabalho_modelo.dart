import '../../../pedidos/dados/modelos/pedido_modelo.dart';
import '../../../../nucleo/dados/leitura_json.dart';

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
    final prestador = lerObjecto(json['prestador']);
    final concurso = lerObjecto(json['concursos']);
    final cliente = lerObjecto(json['cliente']);
    return TrabalhoModelo(
      id: '${json['id']}',
      estado: json['estado'] as String? ?? '',
      prestadorId: '${json['prestador_id']}',
      servico:
          lerTexto(lerObjecto(json['servicos'])?['nome']) ??
          lerTexto(concurso?['titulo']) ??
          'Serviço',
      valorAcordado: (json['valor_acordado'] as num?)?.toInt(),
      prestadorNome: lerTexto(lerObjecto(prestador?['perfis'])?['nome']),
      origemConcurso: json['concurso_id'] != null,
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      concluidoEm: DateTime.tryParse('${json['concluido_em']}')?.toLocal(),
      // Uma avaliação por trabalho; a lista embebida diz se já existe.
      avaliado: lerLista(json['avaliacoes']).isNotEmpty,
      descricao: lerTexto(concurso?['descricao']),
      zona: lerTexto(lerObjecto(concurso?['zonas'])?['nome']),
      endereco: lerTexto(concurso?['endereco']),
      // Com o trabalho criado, a RLS deixa o prestador ler o perfil do
      // cliente. Se ainda assim vier nulo, o ecrã diz que não está
      // disponível; não é erro.
      cliente: cliente == null
          ? null
          : ContactoClienteModelo(
              nome: lerTexto(cliente['nome']) ?? '',
              telefone: lerTexto(cliente['telefone']),
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
