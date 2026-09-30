/// Valores do enum `urgencia` (coluna `concursos.quando`).
enum Urgencia {
  hoje('Hoje'),
  estaSemana('Esta semana'),
  semPressa('Sem pressa');

  const Urgencia(this.rotulo);

  final String rotulo;

  /// Nome na base (`esta_semana`, …).
  String get valor => switch (this) {
    hoje => 'hoje',
    estaSemana => 'esta_semana',
    semPressa => 'sem_pressa',
  };

  static Urgencia? deTexto(String? v) =>
      Urgencia.values.where((u) => u.valor == v).firstOrNull;
}

/// Valores do enum `estado_concurso`.
enum EstadoConcurso {
  aberto('Aberto'),
  adjudicado('Adjudicado'),
  cancelado('Cancelado'),
  expirado('Fechado');

  const EstadoConcurso(this.rotulo);

  final String rotulo;

  static EstadoConcurso deTexto(String? v) => EstadoConcurso.values.firstWhere(
    (e) => e.name == v,
    orElse: () => EstadoConcurso.aberto,
  );
}

/// Valores do enum `tipo_proposta`.
enum TipoProposta {
  aceitaOrcamento('Aceita', 'aceita_orcamento'),
  contraproposta('Contraproposta', 'contraproposta');

  const TipoProposta(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  static TipoProposta deTexto(String? v) => TipoProposta.values.firstWhere(
    (t) => t.valor == v,
    orElse: () => TipoProposta.aceitaOrcamento,
  );
}

/// Valores do enum `estado_proposta`.
enum EstadoProposta {
  enviada,
  escolhida,
  naoEscolhida,
  retirada;

  static EstadoProposta deTexto(String? v) => switch (v) {
    'escolhida' => escolhida,
    'nao_escolhida' => naoEscolhida,
    'retirada' => retirada,
    _ => enviada,
  };
}

/// O que o cliente envia para `concursos`. `estado` fica com o valor por
/// omissão (`aberto`); `fecha_em` é agora + 48 h, como a especificação pede.
class NovoConcursoModelo {
  const NovoConcursoModelo({
    required this.clienteId,
    required this.categoriaId,
    required this.servicoId,
    required this.titulo,
    required this.descricao,
    required this.orcamento,
    required this.quando,
    required this.zonaId,
    required this.fechaEm,
    this.endereco,
  });

  static const duracao = Duration(hours: 48);

  final String clienteId;
  final String categoriaId;
  final String servicoId;
  final String titulo;
  final String descricao;
  final int orcamento;
  final Urgencia quando;
  final String zonaId;
  final DateTime fechaEm;
  final String? endereco;

  Map<String, dynamic> toJson() => {
    'cliente_id': clienteId,
    'categoria_id': categoriaId,
    'servico_id': servicoId,
    'titulo': titulo,
    'descricao': descricao,
    'orcamento_cliente': orcamento,
    'quando': quando.valor,
    'zona_id': zonaId,
    'fecha_em': fechaEm.toUtc().toIso8601String(),
    'endereco': ?endereco,
  };
}

/// Um concurso, para o cliente e para o prestador.
class ConcursoModelo {
  const ConcursoModelo({
    required this.id,
    required this.titulo,
    required this.estado,
    this.descricao = '',
    this.orcamento,
    this.quando,
    this.fechaEm,
    this.criadoEm,
    this.servico,
    this.zona,
    this.municipio,
    this.numeroPropostas,
    this.jaRespondido = false,
  });

  factory ConcursoModelo.fromJson(
    Map<String, dynamic> json, {
    String? prestadorId,
  }) {
    final zona = json['zonas'] as Map<String, dynamic>?;
    final propostas = (json['propostas'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    return ConcursoModelo(
      id: '${json['id']}',
      titulo: json['titulo'] as String? ?? 'Concurso',
      estado: EstadoConcurso.deTexto(json['estado'] as String?),
      descricao: json['descricao'] as String? ?? '',
      orcamento: (json['orcamento_cliente'] as num?)?.toInt(),
      quando: Urgencia.deTexto(json['quando'] as String?),
      fechaEm: DateTime.tryParse('${json['fecha_em']}')?.toLocal(),
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      servico: (json['servicos'] as Map<String, dynamic>?)?['nome'] as String?,
      zona: zona?['nome'] as String?,
      municipio: zona?['municipio'] as String?,
      // A lista de propostas embebida só traz o que a RLS deixa ver: ao
      // cliente, todas as do seu concurso; ao prestador, só as dele.
      numeroPropostas: propostas?.length,
      jaRespondido:
          prestadorId != null &&
          (propostas ?? const []).any(
            (p) => '${p['prestador_id']}' == prestadorId,
          ),
    );
  }

  final String id;
  final String titulo;
  final EstadoConcurso estado;
  final String descricao;
  final int? orcamento;
  final Urgencia? quando;
  final DateTime? fechaEm;
  final DateTime? criadoEm;
  final String? servico;
  final String? zona;
  final String? municipio;
  final int? numeroPropostas;
  final bool jaRespondido;
}

/// Faixa de referência de `vw_referencia_precos` (percentis 25 e 75).
class ReferenciaPrecoModelo {
  const ReferenciaPrecoModelo({
    required this.minimo,
    required this.maximo,
    required this.amostras,
  });

  final int minimo;
  final int maximo;
  final int amostras;
}

/// O que o prestador envia para `propostas`. `estado` fica `enviada` pelo
/// valor por omissão.
class NovaPropostaModelo {
  const NovaPropostaModelo({
    required this.concursoId,
    required this.prestadorId,
    required this.tipo,
    required this.valor,
    this.justificacao,
  });

  /// Mínimo exigido pela restrição da base para uma contraproposta.
  static const justificacaoMinima = 15;

  final String concursoId;
  final String prestadorId;
  final TipoProposta tipo;
  final int valor;
  final String? justificacao;

  Map<String, dynamic> toJson() => {
    'concurso_id': concursoId,
    'prestador_id': prestadorId,
    'tipo': tipo.valor,
    'valor': valor,
    'justificacao': ?justificacao,
  };
}

/// Uma proposta, como o cliente a vê ao escolher.
class PropostaModelo {
  const PropostaModelo({
    required this.id,
    required this.prestadorId,
    required this.nome,
    required this.tipo,
    required this.valor,
    required this.estado,
    this.justificacao,
    this.avaliacaoMedia,
    this.servicosFeitos = 0,
    this.verificado = false,
    this.fotoCaminho,
  });

  factory PropostaModelo.fromJson(Map<String, dynamic> json) {
    final prestador = json['prestadores'] as Map<String, dynamic>?;
    final perfil = prestador?['perfis'] as Map<String, dynamic>?;
    return PropostaModelo(
      id: '${json['id']}',
      prestadorId: '${json['prestador_id']}',
      nome: perfil?['nome'] as String? ?? 'Prestador',
      tipo: TipoProposta.deTexto(json['tipo'] as String?),
      valor: (json['valor'] as num?)?.toInt() ?? 0,
      estado: EstadoProposta.deTexto(json['estado'] as String?),
      justificacao: json['justificacao'] as String?,
      avaliacaoMedia: (prestador?['avaliacao_media'] as num?)?.toDouble(),
      servicosFeitos: (prestador?['servicos_feitos'] as num?)?.toInt() ?? 0,
      verificado: prestador?['verificado'] as bool? ?? false,
      fotoCaminho: perfil?['foto'] as String?,
    );
  }

  final String id;
  final String prestadorId;
  final String nome;
  final TipoProposta tipo;
  final int valor;
  final EstadoProposta estado;
  final String? justificacao;
  final double? avaliacaoMedia;
  final int servicosFeitos;
  final bool verificado;
  final String? fotoCaminho;
}
