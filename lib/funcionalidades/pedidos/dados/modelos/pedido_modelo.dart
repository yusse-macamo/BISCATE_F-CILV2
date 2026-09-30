/// Valores do enum `estado_pedido` na base.
enum EstadoPedido {
  pendente,
  aceite,
  rejeitado,
  cancelado;

  static EstadoPedido deTexto(String? valor) => EstadoPedido.values.firstWhere(
    (e) => e.name == valor,
    orElse: () => EstadoPedido.pendente,
  );
}

/// Valores do enum `periodo_dia` na base. Não há "noite".
enum PeriodoDia {
  manha('Manhã'),
  tarde('Tarde'),
  qualquer('Qualquer hora');

  const PeriodoDia(this.rotulo);

  final String rotulo;

  static PeriodoDia? deTexto(String? valor) =>
      PeriodoDia.values.where((p) => p.name == valor).firstOrNull;
}

/// O que a app envia para `pedidos` ao solicitar um serviço. `estado` fica
/// com o valor por omissão da tabela (`pendente`); a app não o escreve.
class NovoPedidoModelo {
  const NovoPedidoModelo({
    required this.clienteId,
    required this.prestadorId,
    required this.servicoId,
    required this.descricao,
    required this.dataPreferida,
    required this.periodo,
    required this.zonaId,
    required this.endereco,
  });

  final String clienteId;
  final String prestadorId;
  final String servicoId;
  final String descricao;
  final DateTime dataPreferida;
  final PeriodoDia periodo;
  final String zonaId;
  final String endereco;

  Map<String, dynamic> toJson() => {
    'cliente_id': clienteId,
    'prestador_id': prestadorId,
    'servico_id': servicoId,
    'descricao': descricao,
    'data_preferida': _data(dataPreferida),
    'periodo': periodo.name,
    'zona_id': zonaId,
    'endereco': endereco,
  };

  /// `date` do Postgres: só o dia, sem hora nem fuso.
  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Contacto do cliente. Só é legível (RLS) depois de existir o trabalho;
/// antes disso a consulta devolve vazio, e isso é normal.
class ContactoClienteModelo {
  const ContactoClienteModelo({required this.nome, this.telefone});

  final String nome;
  final String? telefone;
}

/// O trabalho criado por `aceitar_pedido`.
class TrabalhoResumoModelo {
  const TrabalhoResumoModelo({required this.estado, this.valorAcordado});

  /// `estado_trabalho` da base. Só interessa se está concluído ou cancelado;
  /// qualquer outro valor é "em curso".
  final String estado;
  final int? valorAcordado;

  bool get concluido => estado == 'concluido';
  bool get cancelado => estado == 'cancelado';
}

/// Um pedido, como o cliente e o prestador o vêem.
class PedidoModelo {
  const PedidoModelo({
    required this.id,
    required this.estado,
    required this.servico,
    required this.descricao,
    this.dataPreferida,
    this.periodo,
    this.zona,
    this.endereco,
    this.criadoEm,
    this.motivoRejeicao,
    this.numeroAnexos = 0,
    this.prestadorNome,
    this.cliente,
    this.trabalho,
  });

  factory PedidoModelo.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? objecto(Object? valor) => switch (valor) {
      final Map<String, dynamic> mapa => mapa,
      // Um embed um-para-muitos (ex.: `trabalhos`) vem como lista.
      [final Map<String, dynamic> primeiro, ...] => primeiro,
      _ => null,
    };

    final prestador = objecto(json['prestador']);
    final cliente = objecto(json['cliente']);
    final trabalho = objecto(json['trabalhos']);
    return PedidoModelo(
      id: '${json['id']}',
      estado: EstadoPedido.deTexto(json['estado'] as String?),
      servico: objecto(json['servicos'])?['nome'] as String? ?? 'Serviço',
      descricao: json['descricao'] as String? ?? '',
      dataPreferida: DateTime.tryParse('${json['data_preferida']}'),
      periodo: PeriodoDia.deTexto(json['periodo'] as String?),
      zona: objecto(json['zonas'])?['nome'] as String?,
      endereco: json['endereco'] as String?,
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      motivoRejeicao: json['motivo_rejeicao'] as String?,
      numeroAnexos: (json['anexos'] as List<dynamic>?)?.length ?? 0,
      prestadorNome: objecto(prestador?['perfis'])?['nome'] as String?,
      // Antes de aceitar, a RLS esconde o perfil do cliente: `cliente` vem
      // nulo. Não é erro.
      cliente: cliente == null
          ? null
          : ContactoClienteModelo(
              nome: cliente['nome'] as String? ?? '',
              telefone: cliente['telefone'] as String?,
            ),
      trabalho: trabalho == null
          ? null
          : TrabalhoResumoModelo(
              estado: trabalho['estado'] as String? ?? '',
              valorAcordado: (trabalho['valor_acordado'] as num?)?.toInt(),
            ),
    );
  }

  final String id;
  final EstadoPedido estado;
  final String servico;
  final String descricao;
  final DateTime? dataPreferida;
  final PeriodoDia? periodo;
  final String? zona;
  final String? endereco;
  final DateTime? criadoEm;
  final String? motivoRejeicao;
  final int numeroAnexos;
  final String? prestadorNome;
  final ContactoClienteModelo? cliente;
  final TrabalhoResumoModelo? trabalho;
}
