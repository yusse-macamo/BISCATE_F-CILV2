import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';

final favoritosRepositorioProvider = Provider<FavoritosRepositorio>(
  (ref) => FavoritosRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// `favoritos(cliente_id, prestador_id)`.
class FavoritosRepositorio {
  FavoritosRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<bool> eFavorito(String clienteId, String prestadorId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('favoritos')
            .select('prestador_id')
            .eq('cliente_id', clienteId)
            .eq('prestador_id', prestadorId)
            .maybeSingle();
        return linha != null;
      });

  /// Marca como favorito. Se já estava, não faz nada.
  Future<void> adicionar(String clienteId, String prestadorId) =>
      executarTraduzido(
        () => _cliente
            .from('favoritos')
            .upsert(
              {'cliente_id': clienteId, 'prestador_id': prestadorId},
              onConflict: 'cliente_id,prestador_id',
              ignoreDuplicates: true,
            ),
      );

  Future<void> remover(String clienteId, String prestadorId) =>
      executarTraduzido(
        () => _cliente
            .from('favoritos')
            .delete()
            .eq('cliente_id', clienteId)
            .eq('prestador_id', prestadorId),
      );
}
