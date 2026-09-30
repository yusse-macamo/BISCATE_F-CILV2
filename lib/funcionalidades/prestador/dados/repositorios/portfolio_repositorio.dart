import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';

final portfolioRepositorioProvider = Provider<PortfolioRepositorio>(
  (ref) => PortfolioRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Uma fotografia da galeria (`portfolio`, `tipo = foto`). O ficheiro está
/// no bucket `publico`, no caminho gravado na base.
class FotoPortfolioModelo {
  const FotoPortfolioModelo({
    required this.id,
    required this.caminho,
    required this.url,
    this.legenda,
    this.ordem,
  });

  final String id;
  final String caminho;

  /// URL público, montado a partir de [caminho].
  final String? url;
  final String? legenda;
  final int? ordem;
}

/// Galeria de trabalhos do prestador. Só fotografias nesta fase; o vídeo
/// fica para depois.
class PortfolioRepositorio {
  PortfolioRepositorio(this._cliente);

  final SupabaseClient _cliente;

  static const _tipoFoto = 'foto';

  Future<List<FotoPortfolioModelo>> listar(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('portfolio')
            .select('id, caminho, legenda, ordem')
            .eq('prestador_id', prestadorId)
            .eq('tipo', _tipoFoto)
            .order('ordem', nullsFirst: false)
            .order('criado_em');
        return [
          for (final l in linhas)
            FotoPortfolioModelo(
              id: '${l['id']}',
              caminho: l['caminho'] as String? ?? '',
              url: urlFotoPerfil(_cliente, l['caminho'] as String?),
              legenda: l['legenda'] as String?,
              ordem: (l['ordem'] as num?)?.toInt(),
            ),
        ];
      });

  /// Envia uma fotografia já comprimida para
  /// `publico/{prestadorId}/portfolio_{millis}.jpg` (sem `upsert`: cada envio
  /// tem nome próprio) e regista-a em `portfolio` com o caminho devolvido.
  Future<void> adicionarFoto({
    required String prestadorId,
    required Uint8List bytes,
    required int ordem,
    String? legenda,
  }) => executarTraduzido(() async {
    final caminho =
        '$prestadorId/portfolio_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
    await _cliente.from('portfolio').insert({
      'prestador_id': prestadorId,
      'tipo': _tipoFoto,
      'caminho': caminho,
      'legenda': ?legenda,
      'ordem': ordem,
    });
  });

  /// Tira a fotografia da galeria (a linha) e depois tenta apagar o ficheiro.
  /// A galeria só depende da linha: se apagar o ficheiro falhar, a foto já
  /// não aparece e o ficheiro fica órfão no Storage, sem erro para o
  /// utilizador.
  Future<void> remover(FotoPortfolioModelo foto) => executarTraduzido(() async {
    await _cliente.from('portfolio').delete().eq('id', foto.id);
    if (foto.caminho.isEmpty) return;
    try {
      await _cliente.storage.from(bucketPublico).remove([foto.caminho]);
    } catch (erro, pilha) {
      registarErroOriginal(erro, pilha);
    }
  });
}
