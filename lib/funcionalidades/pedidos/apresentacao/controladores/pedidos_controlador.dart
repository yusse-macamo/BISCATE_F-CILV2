import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/modelos/pedido_modelo.dart';
import '../../dados/repositorios/pedidos_repositorio.dart';

/// Em que ponto está um pedido, juntando o estado do pedido e o do trabalho
/// que `aceitar_pedido` cria.
enum SituacaoPedido {
  pendente('Pendente'),
  emCurso('Aceite'),
  concluido('Concluído'),
  rejeitado('Rejeitado'),
  cancelado('Cancelado');

  const SituacaoPedido(this.rotulo);

  final String rotulo;

  bool get activa => this == pendente || this == emCurso;
}

SituacaoPedido situacaoDe(PedidoModelo pedido) => switch (pedido.estado) {
  EstadoPedido.pendente => SituacaoPedido.pendente,
  EstadoPedido.rejeitado => SituacaoPedido.rejeitado,
  EstadoPedido.cancelado => SituacaoPedido.cancelado,
  EstadoPedido.aceite => switch (pedido.trabalho) {
    final t? when t.concluido => SituacaoPedido.concluido,
    final t? when t.cancelado => SituacaoPedido.cancelado,
    _ => SituacaoPedido.emCurso,
  },
};

Future<String> _utilizador(Ref ref) async {
  await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
  final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
  if (id == null) {
    throw const FalhaApp('Entre na sua conta para ver os seus pedidos.');
  }
  return id;
}

/// Pedidos feitos pelo cliente autenticado (tela 08).
final pedidosClienteProvider = FutureProvider.autoDispose<List<PedidoModelo>>((
  ref,
) async {
  final clienteId = await _utilizador(ref);
  return ref.watch(pedidosRepositorioProvider).doCliente(clienteId);
});

/// Pedidos recebidos pelo prestador autenticado (tela 14 e painel).
final pedidosPrestadorProvider = FutureProvider.autoDispose<List<PedidoModelo>>(
  (ref) async {
    final prestadorId = await _utilizador(ref);
    return ref.watch(pedidosRepositorioProvider).doPrestador(prestadorId);
  },
);

/// Aceitar e rejeitar do lado do prestador. O estado é o conjunto dos pedidos
/// com uma resposta a caminho, para desactivar os botões desse cartão.
final respostaPedidoControladorProvider =
    NotifierProvider.autoDispose<RespostaPedidoControlador, Set<String>>(
      RespostaPedidoControlador.new,
    );

class RespostaPedidoControlador extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Chama `aceitar_pedido`, que cria o trabalho. Devolve a mensagem de erro,
  /// ou `null` se correu bem.
  Future<String?> aceitar(String pedidoId, {int? valorAcordado}) => _responder(
    pedidoId,
    () => ref
        .read(pedidosRepositorioProvider)
        .aceitar(pedidoId, valorAcordado: valorAcordado),
  );

  Future<String?> rejeitar(String pedidoId) => _responder(
    pedidoId,
    () => ref.read(pedidosRepositorioProvider).rejeitar(pedidoId),
  );

  Future<String?> _responder(
    String pedidoId,
    Future<void> Function() accao,
  ) async {
    if (state.contains(pedidoId)) return null;
    state = {...state, pedidoId};
    try {
      await accao();
      // Relê: depois de aceitar, o contacto do cliente passa a ser legível.
      ref.invalidate(pedidosPrestadorProvider);
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = {...state}..remove(pedidoId);
    }
  }
}

// ── Apresentação ───────────────────────────────────────────────────────────

const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _meses = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Hoje", "Amanhã" ou "Sáb, 4 Out".
String rotuloData(DateTime data, DateTime hoje) {
  final dias = _dia(data).difference(_dia(hoje)).inDays;
  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Amanhã';
  return '${_diasSemana[data.weekday - 1]}, ${data.day} ${_meses[data.month - 1]}';
}

/// "Sáb, 4 Out · Manhã", ou só uma das partes se faltar a outra.
String quandoDe(PedidoModelo pedido, DateTime hoje) => [
  if (pedido.dataPreferida case final data?) rotuloData(data, hoje),
  ?pedido.periodo?.rotulo,
].join(' · ');

/// "Há 12 min", "Há 3 h", "Há 2 dias".
String haQuanto(DateTime? criadoEm, DateTime agora) {
  if (criadoEm == null) return '';
  final d = agora.difference(criadoEm);
  if (d.inMinutes < 1) return 'Agora';
  if (d.inHours < 1) return 'Há ${d.inMinutes} min';
  if (d.inDays < 1) return 'Há ${d.inHours} h';
  return d.inDays == 1 ? 'Há 1 dia' : 'Há ${d.inDays} dias';
}

String textoValor(int? valor) =>
    valor == null ? 'Valor a combinar' : '${formatarMt(valor)} MT';
