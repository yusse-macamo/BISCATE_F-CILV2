import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../modelos/pedido_modelo.dart';

final pedidosRepositorioProvider = Provider<PedidosRepositorio>(
  (ref) => PedidosRepositorio(ref.watch(clienteSupabaseProvider)),
);

class PedidosRepositorio {
  PedidosRepositorio(this._cliente);

  final SupabaseClient _cliente;

  static const _campos =
      'id, estado, descricao, data_preferida, periodo, endereco, criado_em, '
      'motivo_rejeicao, '
      'servicos(nome), zonas(nome), anexos(id), '
      'trabalhos(estado, valor_acordado), '
      'prestador:prestadores(perfis!prestadores_perfil_id_fkey(nome)), '
      // Só legível depois de existir o trabalho; antes, a RLS devolve nulo.
      'cliente:perfis!pedidos_cliente_id_fkey(nome, telefone)';

  /// Insere o pedido e devolve o `id`.
  Future<String> criar(NovoPedidoModelo pedido) => executarTraduzido(() async {
    final linha = await _cliente
        .from('pedidos')
        .insert(pedido.toJson())
        .select('id')
        .single();
    return '${linha['id']}';
  });

  /// Envia uma fotografia já comprimida para
  /// `publico/{clienteId}/pedido_{millis}.jpg` (sem `upsert`: cada envio tem
  /// nome próprio) e regista o caminho em `anexos` com o `pedido_id`.
  Future<void> anexar({
    required String clienteId,
    required String pedidoId,
    required Uint8List bytes,
  }) => executarTraduzido(() async {
    final caminho =
        '$clienteId/pedido_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _cliente.storage
        .from(bucketPublico)
        .uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    await _cliente.from('anexos').insert({
      'pedido_id': pedidoId,
      'caminho': caminho,
    });
  });

  Future<List<PedidoModelo>> doCliente(String clienteId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('pedidos')
            .select(_campos)
            .eq('cliente_id', clienteId)
            .order('criado_em', ascending: false);
        return linhas.map(PedidoModelo.fromJson).toList();
      });

  Future<List<PedidoModelo>> doPrestador(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('pedidos')
            .select(_campos)
            .eq('prestador_id', prestadorId)
            .order('criado_em', ascending: false);
        return linhas.map(PedidoModelo.fromJson).toList();
      });

  /// Aceita pela função do servidor, que cria a linha em `trabalhos`. A app
  /// nunca insere em `trabalhos`. [valorAcordado] pode ser nulo.
  Future<void> aceitar(String pedidoId, {int? valorAcordado}) =>
      executarTraduzido(
        () => _cliente.rpc(
          'aceitar_pedido',
          params: {'p_pedido': pedidoId, 'p_valor': valorAcordado},
        ),
      );

  /// Rejeitar é só mudar o estado.
  Future<void> rejeitar(String pedidoId) => executarTraduzido(
    () => _cliente
        .from('pedidos')
        .update({'estado': EstadoPedido.rejeitado.name})
        .eq('id', pedidoId),
  );
}
