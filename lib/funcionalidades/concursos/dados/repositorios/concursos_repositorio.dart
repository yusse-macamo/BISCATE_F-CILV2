import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../modelos/concurso_modelo.dart';

final concursosRepositorioProvider = Provider<ConcursosRepositorio>(
  (ref) => ConcursosRepositorio(ref.watch(clienteSupabaseProvider)),
);

class ConcursosRepositorio {
  ConcursosRepositorio(this._cliente);

  final SupabaseClient _cliente;

  static const _campos =
      'id, cliente_id, titulo, descricao, estado, orcamento_cliente, quando, '
      'fecha_em, '
      'criado_em, servicos(nome), zonas(nome, municipio), '
      'propostas(prestador_id)';

  // ── Cliente ──────────────────────────────────────────────────────────────

  Future<String> publicar(NovoConcursoModelo concurso) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('concursos')
            .insert(concurso.toJson())
            .select('id')
            .single();
        return '${linha['id']}';
      });

  /// Fotografia já comprimida, em `publico/{clienteId}/concurso_{millis}.jpg`
  /// (sem `upsert`: cada envio tem nome próprio), registada em `anexos` com o
  /// `concurso_id`.
  Future<void> anexar({
    required String clienteId,
    required String concursoId,
    required Uint8List bytes,
  }) => executarTraduzido(() async {
    final caminho =
        '$clienteId/concurso_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      'concurso_id': concursoId,
      'caminho': caminho,
    });
  });

  /// Faixa de preços de serviços parecidos no município, ou `null` se a vista
  /// não tiver linha: nesse caso não se mostra faixa nenhuma.
  Future<ReferenciaPrecoModelo?> referencia({
    required String servicoId,
    required String municipio,
  }) => executarTraduzido(() async {
    final linha = await _cliente
        .from('vw_referencia_precos')
        .select('p25, p75, n')
        .eq('servico_id', servicoId)
        .eq('municipio', municipio)
        .maybeSingle();
    final p25 = (linha?['p25'] as num?)?.round();
    final p75 = (linha?['p75'] as num?)?.round();
    if (p25 == null || p75 == null) return null;
    return ReferenciaPrecoModelo(
      minimo: p25,
      maximo: p75,
      amostras: (linha?['n'] as num?)?.toInt() ?? 0,
    );
  });

  Future<List<ConcursoModelo>> doCliente(String clienteId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('concursos')
            .select(_campos)
            .eq('cliente_id', clienteId)
            .order('criado_em', ascending: false);
        return [for (final l in linhas) ConcursoModelo.fromJson(l)];
      });

  Future<ConcursoModelo?> obter(String concursoId, {String? prestadorId}) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('concursos')
            .select(_campos)
            .eq('id', concursoId)
            .maybeSingle();
        return linha == null
            ? null
            : ConcursoModelo.fromJson(linha, prestadorId: prestadorId);
      });

  Future<List<PropostaModelo>> propostas(String concursoId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('propostas')
            .select(
              'id, prestador_id, tipo, valor, justificacao, estado, '
              'prestadores(avaliacao_media, servicos_feitos, verificado, '
              'perfis!prestadores_perfil_id_fkey(nome, foto))',
            )
            .eq('concurso_id', concursoId)
            .neq('estado', 'retirada')
            .order('criado_em');
        return [for (final l in linhas) PropostaModelo.fromJson(l)];
      });

  /// Escolhe a proposta: fecha as outras e cria o trabalho, numa só
  /// transacção no servidor. A app não escreve em `trabalhos`.
  Future<void> adjudicar(String propostaId) => executarTraduzido(
    () =>
        _cliente.rpc('adjudicar_concurso', params: {'p_proposta': propostaId}),
  );

  // ── Prestador ────────────────────────────────────────────────────────────

  /// Concursos abertos da categoria do prestador, nas zonas onde atende.
  Future<List<ConcursoModelo>> oportunidades({
    required String prestadorId,
    required String categoriaId,
    required List<String> zonaIds,
  }) => executarTraduzido(() async {
    if (zonaIds.isEmpty) return const [];
    final linhas = await _cliente
        .from('concursos')
        .select(_campos)
        .eq('estado', EstadoConcurso.aberto.name)
        .eq('categoria_id', categoriaId)
        // Os concursos que ele próprio publicou não são oportunidades.
        .neq('cliente_id', prestadorId)
        .inFilter('zona_id', zonaIds)
        .order('criado_em', ascending: false);
    return [
      for (final l in linhas)
        ConcursoModelo.fromJson(l, prestadorId: prestadorId),
    ];
  });

  Future<void> responder(NovaPropostaModelo proposta) => executarTraduzido(
    () => _cliente.from('propostas').insert(proposta.toJson()),
  );

  /// Zonas onde o prestador atende (`prestador_zonas`).
  Future<List<String>> zonasDoPrestador(String prestadorId) =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('prestador_zonas')
            .select('zona_id')
            .eq('prestador_id', prestadorId);
        return [for (final l in linhas) '${l['zona_id']}'];
      });
}
