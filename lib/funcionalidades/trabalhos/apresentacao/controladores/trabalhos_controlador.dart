import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../cliente/apresentacao/controladores/perfil_prestador_controlador.dart';
import '../../../cliente/apresentacao/controladores/procura_controlador.dart';
import '../../../pedidos/apresentacao/controladores/pedidos_controlador.dart';
import '../../dados/modelos/trabalho_modelo.dart';
import '../../dados/repositorios/trabalhos_repositorio.dart';

/// Trabalhos do cliente autenticado (de pedidos e de concursos).
final trabalhosClienteProvider =
    FutureProvider.autoDispose<List<TrabalhoModelo>>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para ver os seus trabalhos.');
      }
      return ref.watch(trabalhosRepositorioProvider).doCliente(id);
    });

/// Trabalhos do prestador autenticado vindos de concursos (tela 14).
final trabalhosConcursoPrestadorProvider =
    FutureProvider.autoDispose<List<TrabalhoModelo>>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para ver os seus trabalhos.');
      }
      return ref.watch(trabalhosRepositorioProvider).deConcursosDoPrestador(id);
    });

// ── Ganhos (painel do prestador) ─────────────────────────────────────────

/// Ganhos do mês, a partir de `valor_acordado` dos trabalhos concluídos.
@immutable
class ResumoGanhos {
  const ResumoGanhos({
    required this.mesActual,
    required this.mesAnterior,
    required this.nomeMesAnterior,
  });

  final int mesActual;
  final int mesAnterior;
  final String nomeMesAnterior;

  /// Percentagem face ao mês anterior, arredondada. `null` quando o mês
  /// anterior não teve ganhos: sem base, a variação não tem sentido e
  /// esconde-se.
  int? get variacao => mesAnterior <= 0
      ? null
      : (((mesActual - mesAnterior) / mesAnterior) * 100).round();
}

const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Soma os ganhos do mês de [agora] e do mês anterior.
ResumoGanhos resumirGanhos(
  List<(int valor, DateTime concluidoEm)> trabalhos,
  DateTime agora,
) {
  final inicioActual = DateTime(agora.year, agora.month);
  final inicioAnterior = DateTime(agora.year, agora.month - 1);
  var actual = 0;
  var anterior = 0;
  for (final (valor, data) in trabalhos) {
    if (!data.isBefore(inicioActual)) {
      actual += valor;
    } else if (!data.isBefore(inicioAnterior)) {
      anterior += valor;
    }
  }
  return ResumoGanhos(
    mesActual: actual,
    mesAnterior: anterior,
    nomeMesAnterior: _meses[inicioAnterior.month - 1],
  );
}

final ganhosPrestadorProvider = FutureProvider.autoDispose<ResumoGanhos>((
  ref,
) async {
  await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
  final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
  if (id == null) {
    throw const FalhaApp('Entre na sua conta para ver os seus ganhos.');
  }
  final agora = DateTime.now();
  final trabalhos = await ref
      .watch(trabalhosRepositorioProvider)
      .ganhosDoPrestador(id, desde: DateTime(agora.year, agora.month - 1));
  return resumirGanhos(trabalhos, agora);
});

// ── Concluir ───────────────────────────────────────────────────────────────

/// `id` dos trabalhos a ser concluídos, para desactivar o botão.
final conclusaoControladorProvider =
    NotifierProvider.autoDispose<ConclusaoControlador, Set<String>>(
      ConclusaoControlador.new,
    );

class ConclusaoControlador extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// `update` de `trabalhos.estado` para `concluido`. Só o cliente o pode
  /// fazer (a RLS impede o prestador). Devolve a mensagem de erro, ou `null`.
  Future<String?> concluir(String trabalhoId) async {
    if (state.contains(trabalhoId)) return null;
    state = {...state, trabalhoId};
    try {
      await ref.read(trabalhosRepositorioProvider).concluir(trabalhoId);
      ref
        ..invalidate(trabalhosClienteProvider)
        ..invalidate(pedidosClienteProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = {...state}..remove(trabalhoId);
    }
  }
}

// ── Avaliar (tela 09) ──────────────────────────────────────────────────────

@immutable
class EstadoAvaliacao {
  const EstadoAvaliacao({
    this.estrelas = 0,
    this.recomenda,
    this.erros = const {},
    this.aEnviar = false,
    this.erroEnvio,
    this.enviada = false,
  });

  final int estrelas;
  final bool? recomenda;

  /// `estrelas`, `recomenda`, `comentario`.
  final Map<String, String> erros;
  final bool aEnviar;
  final String? erroEnvio;
  final bool enviada;

  EstadoAvaliacao copiarCom({
    int? estrelas,
    bool? recomenda,
    Map<String, String>? erros,
    bool? aEnviar,
    String? erroEnvio,
    bool limparErroEnvio = false,
    bool? enviada,
  }) => EstadoAvaliacao(
    estrelas: estrelas ?? this.estrelas,
    recomenda: recomenda ?? this.recomenda,
    erros: erros ?? this.erros,
    aEnviar: aEnviar ?? this.aEnviar,
    erroEnvio: limparErroEnvio ? null : (erroEnvio ?? this.erroEnvio),
    enviada: enviada ?? this.enviada,
  );
}

/// A família é pelo `id` do trabalho.
final avaliacaoControladorProvider = NotifierProvider.autoDispose
    .family<AvaliacaoControlador, EstadoAvaliacao, String>(
      AvaliacaoControlador.new,
    );

class AvaliacaoControlador
    extends AutoDisposeFamilyNotifier<EstadoAvaliacao, String> {
  static const comentarioMaximo = 500;
  static const rotulos = [
    'Muito mau',
    'Mau',
    'Razoável',
    'Muito bom',
    'Excelente',
  ];

  @override
  EstadoAvaliacao build(String trabalhoId) => const EstadoAvaliacao();

  void escolherEstrelas(int n) => state = state.copiarCom(
    estrelas: n.clamp(1, 5),
    erros: {...state.erros}..remove('estrelas'),
  );

  void escolherRecomenda(bool v) => state = state.copiarCom(
    recomenda: v,
    erros: {...state.erros}..remove('recomenda'),
  );

  /// Insere a avaliação. A base recusa se o trabalho não estiver concluído
  /// ou não for de quem avalia, e só aceita uma por trabalho. Depois relê o
  /// perfil do prestador: a média e a percentagem vêm do gatilho.
  Future<void> enviar({
    required String prestadorId,
    required String comentario,
  }) async {
    if (state.aEnviar || state.enviada) return;
    final texto = comentario.trim();
    final erros = {
      if (state.estrelas < 1) 'estrelas': 'Escolha de 1 a 5 estrelas.',
      if (state.recomenda == null)
        'recomenda': 'Diga se recomendaria a um amigo.',
      if (texto.length > comentarioMaximo)
        'comentario': 'Escreva no máximo $comentarioMaximo caracteres.',
    };
    if (erros.isNotEmpty) {
      state = state.copiarCom(erros: erros);
      return;
    }

    state = state.copiarCom(aEnviar: true, limparErroEnvio: true);
    try {
      await ref
          .read(trabalhosRepositorioProvider)
          .avaliar(
            NovaAvaliacaoModelo(
              trabalhoId: arg,
              estrelas: state.estrelas,
              recomenda: state.recomenda!,
              comentario: texto.isEmpty ? null : texto,
            ),
          );
      state = state.copiarCom(aEnviar: false, enviada: true);
      // A app não calcula a média: relê o que o gatilho actualizou.
      ref
        ..invalidate(trabalhosClienteProvider)
        ..invalidate(perfilPrestadorProvider(prestadorId))
        ..invalidate(avaliacoesPrestadorProvider(prestadorId))
        ..invalidate(resultadosProcuraProvider)
        ..invalidate(destaquesProvider);
    } on FalhaApp catch (falha) {
      state = state.copiarCom(
        aEnviar: false,
        erroEnvio: falha.mensagem == 'Este registo já existe.'
            ? 'Já avaliou este trabalho.'
            : falha.mensagem,
      );
    }
  }
}
