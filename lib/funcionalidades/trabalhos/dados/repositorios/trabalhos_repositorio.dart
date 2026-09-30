import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../modelos/trabalho_modelo.dart';

final trabalhosRepositorioProvider = Provider<TrabalhosRepositorio>(
  (ref) => TrabalhosRepositorio(ref.watch(clienteSupabaseProvider)),
);

class TrabalhosRepositorio {
  TrabalhosRepositorio(this._cliente);

  final SupabaseClient _cliente;

  /// Todos os trabalhos do cliente, venham de um pedido ou de um concurso.
  Future<List<TrabalhoModelo>> doCliente(String clienteId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('trabalhos')
            .select(
              'id, estado, valor_acordado, criado_em, concluido_em, '
              'prestador_id, concurso_id, '
              'servicos(nome), concursos(titulo), avaliacoes(id), '
              'prestador:prestadores(perfis!prestadores_perfil_id_fkey(nome))',
            )
            .eq('cliente_id', clienteId)
            .order('criado_em', ascending: false);
        return [for (final l in linhas) TrabalhoModelo.fromJson(l)];
      });

  /// Trabalhos do prestador que vieram de concursos adjudicados. Os que vêm
  /// de pedidos já aparecem com o pedido, na gestão de pedidos.
  Future<List<TrabalhoModelo>> deConcursosDoPrestador(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('trabalhos')
            .select(
              'id, estado, valor_acordado, criado_em, concluido_em, '
              'prestador_id, concurso_id, servicos(nome), '
              'concursos(titulo, descricao, endereco, zonas(nome)), '
              'cliente:perfis!trabalhos_cliente_id_fkey(nome, telefone)',
            )
            .eq('prestador_id', prestadorId)
            .not('concurso_id', 'is', null)
            .order('criado_em', ascending: false);
        return [for (final l in linhas) TrabalhoModelo.fromJson(l)];
      });

  /// Marca o trabalho como concluído. Só o cliente o pode fazer: a RLS
  /// impede o prestador.
  Future<void> concluir(String trabalhoId) => executarTraduzido(
    () => _cliente
        .from('trabalhos')
        .update({'estado': 'concluido'})
        .eq('id', trabalhoId),
  );

  Future<void> avaliar(NovaAvaliacaoModelo avaliacao) => executarTraduzido(
    () => _cliente.from('avaliacoes').insert(avaliacao.toJson()),
  );
}
