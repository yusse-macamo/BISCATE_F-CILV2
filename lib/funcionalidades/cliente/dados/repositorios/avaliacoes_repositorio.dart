import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';

final avaliacoesRepositorioProvider = Provider<AvaliacoesRepositorio>(
  (ref) => AvaliacoesRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Linha de `avaliacoes`, para o perfil do prestador.
class AvaliacaoModelo {
  const AvaliacaoModelo({
    required this.estrelas,
    this.comentario,
    this.recomenda,
    this.criadoEm,
    this.autor,
  });

  factory AvaliacaoModelo.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'] as Map<String, dynamic>?;
    return AvaliacaoModelo(
      estrelas: (json['estrelas'] as num?)?.toInt() ?? 0,
      comentario: json['comentario'] as String?,
      recomenda: json['recomenda'] as bool?,
      criadoEm: DateTime.tryParse('${json['criado_em']}')?.toLocal(),
      autor: cliente?['nome'] as String?,
    );
  }

  final int estrelas;
  final String? comentario;
  final bool? recomenda;
  final DateTime? criadoEm;

  /// Nome de quem avaliou. Pode vir nulo se a RLS não deixar ler o perfil
  /// do cliente; o ecrã mostra "Cliente".
  final String? autor;
}

class AvaliacoesRepositorio {
  AvaliacoesRepositorio(this._cliente);

  final SupabaseClient _cliente;

  /// As avaliações mais recentes do prestador.
  Future<List<AvaliacaoModelo>> recentes(
    String prestadorId, {
    int limite = 3,
  }) => executarTraduzido(() async {
    final linhas = await _cliente
        .from('avaliacoes')
        .select(
          'estrelas, comentario, recomenda, criado_em, '
          'cliente:perfis!avaliacoes_cliente_id_fkey(nome)',
        )
        .eq('prestador_id', prestadorId)
        .order('criado_em', ascending: false)
        .limit(limite);
    return linhas.map(AvaliacaoModelo.fromJson).toList();
  });
}
