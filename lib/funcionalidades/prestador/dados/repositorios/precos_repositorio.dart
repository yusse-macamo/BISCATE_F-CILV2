import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../modelos/preco_modelo.dart';

final precosRepositorioProvider = Provider<PrecosRepositorio>(
  (ref) => PrecosRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Preços do prestador: `precos_prestador` (serviços do catálogo) e
/// `servicos_proprios` (fora do catálogo, máximo de 3 por gatilho).
class PrecosRepositorio {
  PrecosRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<List<PrecoPrestadorModelo>> listarPrecos(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('precos_prestador')
            .select('servico_id, valor')
            .eq('prestador_id', prestadorId);
        return linhas.map(PrecoPrestadorModelo.fromJson).toList();
      });

  /// Cria ou actualiza o preço de um serviço. `valor` nulo grava
  /// "sob orçamento".
  Future<void> guardarPreco(String prestadorId, PrecoPrestadorModelo preco) =>
      executarTraduzido(
        () => _cliente
            .from('precos_prestador')
            .upsert(
              preco.toJson(prestadorId),
              onConflict: 'prestador_id,servico_id',
            ),
      );

  Future<List<ServicoProprioModelo>> listarServicosProprios(
    String prestadorId,
  ) => executarTraduzido(() async {
    final linhas = await _cliente
        .from('servicos_proprios')
        .select('id, nome, valor')
        .eq('prestador_id', prestadorId)
        .order('criado_em');
    return linhas.map(ServicoProprioModelo.fromJson).toList();
  });

  /// Acrescenta um serviço próprio e devolve-o com o `id` da base. Se o
  /// prestador já tiver 3, o gatilho recusa e isto lança [FalhaApp] com a
  /// mensagem do servidor.
  Future<ServicoProprioModelo> adicionarServicoProprio(
    String prestadorId,
    ServicoProprioModelo servico,
  ) => executarTraduzido(() async {
    final linha = await _cliente
        .from('servicos_proprios')
        .insert(servico.toJson(prestadorId))
        .select('id, nome, valor')
        .single();
    return ServicoProprioModelo.fromJson(linha);
  });

  Future<void> alterarValorServicoProprio(String id, int? valor) =>
      executarTraduzido(
        () => _cliente
            .from('servicos_proprios')
            .update({'valor': valor})
            .eq('id', id),
      );

  Future<void> removerServicoProprio(String id) => executarTraduzido(
    () => _cliente.from('servicos_proprios').delete().eq('id', id),
  );
}
