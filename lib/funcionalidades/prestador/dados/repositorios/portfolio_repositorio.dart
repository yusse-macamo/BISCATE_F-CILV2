import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';

final portfolioRepositorioProvider = Provider<PortfolioRepositorio>(
  (ref) => PortfolioRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Valores do enum `tipo_media`.
enum TipoMedia { foto, video }

/// Linha de `portfolio`. O ficheiro está no bucket `publico`.
class ItemPortfolioModelo {
  const ItemPortfolioModelo({
    required this.id,
    required this.tipo,
    required this.url,
    this.legenda,
  });

  final String id;
  final TipoMedia tipo;

  /// URL público, montado a partir do caminho gravado.
  final String? url;
  final String? legenda;
}

class PortfolioRepositorio {
  PortfolioRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<List<ItemPortfolioModelo>> listar(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('portfolio')
            .select('id, tipo, caminho, legenda')
            .eq('prestador_id', prestadorId)
            .order('ordem', nullsFirst: false)
            .order('criado_em', ascending: false);
        return [
          for (final l in linhas)
            ItemPortfolioModelo(
              id: '${l['id']}',
              tipo: l['tipo'] == 'video' ? TipoMedia.video : TipoMedia.foto,
              url: urlFotoPerfil(_cliente, l['caminho'] as String?),
              legenda: l['legenda'] as String?,
            ),
        ];
      });

  /// Envia uma fotografia já comprimida para
  /// `publico/{prestadorId}/portfolio_{millis}.jpg` e regista-a em
  /// `portfolio` com o caminho devolvido.
  Future<void> adicionarFoto({
    required String prestadorId,
    required Uint8List bytes,
    String? legenda,
  }) => executarTraduzido(() async {
    final caminho =
        '$prestadorId/portfolio_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _cliente.storage
        .from(bucketPublico)
        .uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _cliente.from('portfolio').insert({
      'prestador_id': prestadorId,
      'tipo': TipoMedia.foto.name,
      'caminho': caminho,
      'legenda': ?legenda,
    });
  });
}
