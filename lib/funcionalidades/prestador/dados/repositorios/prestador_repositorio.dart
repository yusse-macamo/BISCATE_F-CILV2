import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../modelos/novo_prestador_modelo.dart';
import '../modelos/painel_prestador_modelo.dart';

final prestadorRepositorioProvider = Provider<PrestadorRepositorio>(
  (ref) => PrestadorRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Buckets do Storage. `documentos` é privado (BI e comprovativos, só o dono e
/// a equipa de aprovação); `publico` tem leitura pública (fotos de perfil,
/// capa e portefólio).
abstract final class BucketsPrestador {
  static const documentos = 'documentos';
  static const publico = bucketPublico;
}

class PrestadorRepositorio {
  PrestadorRepositorio(this._cliente);

  final SupabaseClient _cliente;

  /// Estado do registo de prestador (`pendente`, `aprovado`, …), ou `null` se
  /// este perfil não tem registo de prestador.
  Future<String?> obterEstado(String perfilId) => executarTraduzido(() async {
    final linha = await _cliente
        .from('prestadores')
        .select('estado')
        .eq('perfil_id', perfilId)
        .maybeSingle();
    return linha?['estado'] as String?;
  });

  /// O prestador com o perfil, a categoria e as zonas, para o painel. `null`
  /// se este perfil não tem registo de prestador.
  Future<PainelPrestadorModelo?> obterPainel(String perfilId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('prestadores')
            .select(
              'perfil_id, titulo, verificado, '
              'avaliacao_media, total_avaliacoes, servicos_feitos, '
              'pct_recomenda, '
              // Há mais de uma relação entre prestadores e perfis (ex.:
              // favoritos); esta é a do dono do registo.
              'perfis!prestadores_perfil_id_fkey(nome, foto), '
              'categorias(nome), '
              'prestador_zonas(zonas(nome))',
            )
            .eq('perfil_id', perfilId)
            .maybeSingle();
        if (linha == null) return null;
        final perfil = linha['perfis'] as Map<String, dynamic>?;
        return PainelPrestadorModelo.fromJson(
          linha,
          fotoUrl: urlFotoPerfil(_cliente, perfil?['foto'] as String?),
        );
      });

  /// Categoria do prestador, ou `null` se este perfil não tem registo de
  /// prestador.
  Future<String?> obterCategoriaId(String perfilId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('prestadores')
            .select('categoria_id')
            .eq('perfil_id', perfilId)
            .maybeSingle();
        final categoriaId = linha?['categoria_id'];
        return categoriaId == null ? null : '$categoriaId';
      });

  /// Envia uma imagem já comprimida para `{perfilId}/{tipo}_{millis}.jpg` e
  /// devolve esse caminho, que é o que se grava na base.
  ///
  /// Sem `upsert`: cada envio tem nome próprio (carimbo temporal), por isso
  /// nunca substitui um ficheiro existente. O controlador não repete envios
  /// que já correram bem.
  Future<String> carregarImagem({
    required String bucket,
    required String perfilId,
    required String tipo,
    required Uint8List bytes,
  }) {
    final caminho =
        '$perfilId/${tipo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    debugPrint('UPLOAD bucket=$bucket caminho=$caminho');
    return executarTraduzido(() async {
      await _cliente.storage
          .from(bucket)
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      debugPrint('UPLOAD OK bucket=$bucket');
      return caminho;
    });
  }

  /// Grava em `perfis.foto` (o perfil do próprio) o caminho devolvido por
  /// [carregarImagem] para a foto de perfil.
  Future<void> gravarFotoPerfil({
    required String perfilId,
    required String caminho,
  }) => executarTraduzido(
    () => _cliente.from('perfis').update({'foto': caminho}).eq('id', perfilId),
  );

  /// Regista em `documentos` os ficheiros enviados para o bucket privado,
  /// com o caminho devolvido por [carregarImagem]. Exige a linha em
  /// `prestadores` (chave estrangeira), por isso corre depois de [registar].
  Future<void> registarDocumentos({
    required String perfilId,
    required Map<String, String> caminhosPorTipo,
  }) => executarTraduzido(
    () => _cliente.from('documentos').insert([
      for (final MapEntry(key: tipo, value: caminho) in caminhosPorTipo.entries)
        {'prestador_id': perfilId, 'tipo': tipo, 'caminho': caminho},
    ]),
  );

  /// Cria a linha em `prestadores`. Se já existir (uma tentativa anterior
  /// chegou a gravar), não faz nada e não altera a linha existente.
  Future<void> registar(NovoPrestadorModelo prestador) => executarTraduzido(
    () => _cliente
        .from('prestadores')
        .upsert(
          prestador.toJson(),
          onConflict: 'perfil_id',
          ignoreDuplicates: true,
        ),
  );

  /// Associa as zonas onde o prestador atende. Zonas já associadas numa
  /// tentativa anterior são ignoradas.
  Future<void> associarZonas({
    required String perfilId,
    required Set<String> zonaIds,
  }) => executarTraduzido(
    () => _cliente
        .from('prestador_zonas')
        .upsert(
          [
            for (final zonaId in zonaIds)
              {'prestador_id': perfilId, 'zona_id': zonaId},
          ],
          onConflict: 'prestador_id,zona_id',
          ignoreDuplicates: true,
        ),
  );
}
