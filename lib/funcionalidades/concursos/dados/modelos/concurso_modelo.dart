import '../../../../nucleo/dados/leitura_json.dart';

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
    this.servicoId,
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

  /// Nulo quando o cliente escolheu "Outro serviço" e o descreveu no texto.
  final String? servicoId;
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
    this.clienteId,
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
    this.fotosAnexos = const [],
  });

  /// [urlAnexo] converte o caminho de cada anexo (bucket `publico`) no URL
  /// a mostrar; o repositório passa-o. Sem ele, fica o caminho.
  factory ConcursoModelo.fromJson(
    Map<String, dynamic> json, {
    String? prestadorId,
    String? Function(String caminho)? urlAnexo,
  }) {
    final zona = lerObjecto(json['zonas']);
    final propostas = json['propostas'] is List
        ? lerLista(json['propostas'])
        : null;
    return ConcursoModelo(
      id: '${json['id']}',
      titulo: json['titulo'] as String? ?? 'Concurso',
      estado: EstadoConcurso.deTexto(json['estado'] as String?),
      clienteId: json['cliente_id'] == null ? null : '${json['cliente_id']}',
      descricao: json['descricao'] as String? ?? '',
      orcamento: (json['orcamento_cliente'] as num?)?.toInt(),
      quando: Urgencia.deTexto(json['quando'] as String?),
      fechaEm: DateTime.tryParse('${json['fecha_em']}')?.toLocal(),
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      servico: lerTexto(lerObjecto(json['servicos'])?['nome']),
      zona: lerTexto(zona?['nome']),
      municipio: lerTexto(zona?['municipio']),
      // A lista de propostas embebida só traz o que a RLS deixa ver: ao
      // cliente, todas as do seu concurso; ao prestador, só as dele.
      numeroPropostas: propostas?.length,
      jaRespondido:
          prestadorId != null &&
          (propostas ?? const []).any(
            (p) => '${p['prestador_id']}' == prestadorId,
          ),
      fotosAnexos: lerAnexos(json['anexos'], urlAnexo ?? (c) => c),
    );
  }

  final String id;
  final String titulo;
  final EstadoConcurso estado;

  /// Quem publicou. Um prestador não responde a um concurso seu.
  final String? clienteId;
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

  /// URLs das fotografias que o cliente juntou.
  final List<String> fotosAnexos;
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
    final prestador = lerObjecto(json['prestadores']);
    final perfil = lerObjecto(prestador?['perfis']);
    return PropostaModelo(
      id: '${json['id']}',
      prestadorId: '${json['prestador_id']}',
      nome: lerTexto(perfil?['nome']) ?? 'Prestador',
      tipo: TipoProposta.deTexto(json['tipo'] as String?),
      valor: (json['valor'] as num?)?.toInt() ?? 0,
      estado: EstadoProposta.deTexto(json['estado'] as String?),
      justificacao: json['justificacao'] as String?,
      avaliacaoMedia: lerDecimal(prestador?['avaliacao_media']),
      servicosFeitos: lerInteiro(prestador?['servicos_feitos']) ?? 0,
      verificado: lerBooleano(prestador?['verificado']) ?? false,
      fotoCaminho: lerTexto(perfil?['foto']),
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
