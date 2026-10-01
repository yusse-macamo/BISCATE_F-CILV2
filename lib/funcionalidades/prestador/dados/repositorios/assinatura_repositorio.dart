import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/leitura_json.dart';

final assinaturaRepositorioProvider = Provider<AssinaturaRepositorio>(
  (ref) => AssinaturaRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Linha de `planos`.
class PlanoModelo {
  const PlanoModelo({
    required this.id,
    required this.nome,
    required this.preco,
    this.descricao,
  });

  final String id;
  final String nome;
  final int preco;
  final String? descricao;
}

/// A assinatura mais recente do prestador (`assinaturas`).
class AssinaturaModelo {
  const AssinaturaModelo({
    required this.planoId,
    required this.planoNome,
    required this.activa,
    this.fim,
  });

  final String planoId;
  final String planoNome;

  /// `estado_assinatura` = `activa`.
  final bool activa;
  final DateTime? fim;
}

/// Linha de `vw_estado_gratuito`: o que falta do período gratuito. Os limites
/// (dias e trabalhos) vêm de `configuracoes`, na base; a app não os conhece.
class EstadoGratuitoModelo {
  const EstadoGratuitoModelo({
    this.diasRestantes,
    this.trabalhosRestantes,
    this.trabalhosFeitos,
  });

  final int? diasRestantes;
  final int? trabalhosRestantes;
  final int? trabalhosFeitos;
}

/// Linha de `pagamentos` do próprio prestador.
class PagamentoModelo {
  const PagamentoModelo({
    required this.valor,
    this.referencia,
    this.data,
    this.planoNome,
  });

  final int valor;
  final String? referencia;
  final DateTime? data;
  final String? planoNome;
}

/// Só leitura: `planos`, `assinaturas`, `pagamentos` e `configuracoes` são
/// escritos pelo servidor ou pelo administrador.
class AssinaturaRepositorio {
  AssinaturaRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<List<PlanoModelo>> planos() => executarTraduzido(() async {
    final linhas = await _cliente
        .from('planos')
        .select('id, nome, preco, descricao')
        .eq('activo', true)
        .order('ordem');
    return [
      for (final l in linhas)
        PlanoModelo(
          id: '${l['id']}',
          nome: l['nome'] as String,
          preco: (l['preco'] as num?)?.toInt() ?? 0,
          descricao: l['descricao'] as String?,
        ),
    ];
  });

  Future<AssinaturaModelo?> actual(String prestadorId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('assinaturas')
            .select('plano_id, estado, fim, planos(nome)')
            .eq('prestador_id', prestadorId)
            .order('fim', ascending: false, nullsFirst: true)
            .limit(1)
            .maybeSingle();
        if (linha == null) return null;
        final plano = lerObjecto(linha['planos']);
        return AssinaturaModelo(
          planoId: '${linha['plano_id']}',
          planoNome: lerTexto(plano?['nome']) ?? 'Plano',
          activa: linha['estado'] == 'activa',
          fim: DateTime.tryParse('${linha['fim']}')?.toLocal(),
        );
      });

  /// Pagamentos do próprio, do mais recente para o mais antigo.
  Future<List<PagamentoModelo>> pagamentos(
    String prestadorId, {
    int limite = 12,
  }) => executarTraduzido(() async {
    final linhas = await _cliente
        .from('pagamentos')
        .select('valor, referencia, data, assinaturas(planos(nome))')
        .eq('prestador_id', prestadorId)
        .order('data', ascending: false)
        .limit(limite);
    return [
      for (final l in linhas)
        PagamentoModelo(
          valor: (l['valor'] as num?)?.toInt() ?? 0,
          referencia: l['referencia'] as String?,
          data: DateTime.tryParse('${l['data']}')?.toLocal(),
          planoNome: lerTexto(
            lerObjecto(lerObjecto(l['assinaturas'])?['planos'])?['nome'],
          ),
        ),
    ];
  });

  Future<EstadoGratuitoModelo?> estadoGratuito(String prestadorId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('vw_estado_gratuito')
            .select('dias_restantes, trabalhos_restantes, trabalhos_feitos')
            .eq('prestador_id', prestadorId)
            .maybeSingle();
        if (linha == null) return null;
        int? inteiro(String c) => (linha[c] as num?)?.toInt();
        return EstadoGratuitoModelo(
          diasRestantes: inteiro('dias_restantes'),
          trabalhosRestantes: inteiro('trabalhos_restantes'),
          trabalhosFeitos: inteiro('trabalhos_feitos'),
        );
      });
}
