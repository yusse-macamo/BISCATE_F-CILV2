import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../modelos/novo_prestador_modelo.dart';
import '../modelos/painel_prestador_modelo.dart';
import '../modelos/perfil_editavel_modelo.dart';
import '../../../../nucleo/dados/leitura_json.dart';

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
        final perfil = lerObjecto(linha['perfis']);
        return PainelPrestadorModelo.fromJson(
          linha,
          fotoUrl: urlFotoPerfil(_cliente, lerTexto(perfil?['foto'])),
        );
      });

  /// O que o prestador pode editar no seu perfil. `null` se não tem registo
  /// de prestador.
  Future<PerfilEditavelModelo?> obterPerfilEditavel(String perfilId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('prestadores')
            .select(
              'titulo, bio, anos_experiencia, categorias(nome), '
              'prestador_zonas(zona_id), '
              'perfis!prestadores_perfil_id_fkey(telefone, foto)',
            )
            .eq('perfil_id', perfilId)
            .maybeSingle();
        if (linha == null) return null;
        final perfil = lerObjecto(linha['perfis']);
        return PerfilEditavelModelo(
          titulo: linha['titulo'] as String? ?? '',
          bio: linha['bio'] as String? ?? '',
          anosExperiencia: (linha['anos_experiencia'] as num?)?.toInt(),
          categoria: lerTexto(lerObjecto(linha['categorias'])?['nome']),
          zonaIds: {
            for (final z in lerLista(linha['prestador_zonas']))
              if (z['zona_id'] case final zonaId?) '$zonaId',
          },
          telefone: lerTexto(perfil?['telefone']) ?? '',
          fotoUrl: urlFotoPerfil(_cliente, lerTexto(perfil?['foto'])),
        );
      });

  /// Grava em `prestadores` só as colunas que a app pode escrever aqui:
  /// `titulo`, `bio` e `anos_experiencia`.
  Future<void> guardarDadosProfissionais(
    String perfilId, {
    required String? titulo,
    required String? bio,
    required int? anosExperiencia,
  }) => executarTraduzido(
    () => _cliente
        .from('prestadores')
        .update({
          'titulo': titulo,
          'bio': bio,
          'anos_experiencia': anosExperiencia,
        })
        .eq('perfil_id', perfilId),
  );

  /// `perfis.telefone` do próprio (só dígitos; a base normaliza).
  Future<void> guardarTelefone(String perfilId, String telefone) =>
      executarTraduzido(
        () => _cliente
            .from('perfis')
            .update({'telefone': telefone})
            .eq('id', perfilId),
      );

  /// Tira as zonas desmarcadas. As novas entram com [associarZonas].
  Future<void> removerZonas({
    required String perfilId,
    required Set<String> zonaIds,
  }) => executarTraduzido(
    () => _cliente
        .from('prestador_zonas')
        .delete()
        .eq('prestador_id', perfilId)
        .inFilter('zona_id', zonaIds.toList()),
  );

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
