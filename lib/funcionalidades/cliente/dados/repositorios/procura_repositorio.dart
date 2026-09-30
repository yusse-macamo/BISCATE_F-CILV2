import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/fotos_perfil.dart';
import '../modelos/prestador_publico_modelo.dart';

final procuraRepositorioProvider = Provider<ProcuraRepositorio>(
  (ref) => ProcuraRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Ordenações permitidas. Por reputação, ou por serviços feitos; nunca por
/// preço mais baixo.
enum OrdemProcura { reputacao, servicosFeitos }

/// Critérios de uma procura. Todos opcionais; sem nenhum, lista todos os
/// prestadores que a RLS deixa ver.
@immutable
class CriteriosProcura {
  const CriteriosProcura({
    this.textoLivre,
    this.categoriaIds = const [],
    this.categoriaId,
    this.municipio,
    this.zonaId,
    this.verificados = false,
    this.avaliacaoMinima,
    this.ordem = OrdemProcura.reputacao,
    this.limite = 50,
  });

  /// Procurado no nome do prestador (`perfis.nome`), em `titulo` e `bio`,
  /// nos serviços a que deu preço e nos serviços próprios (e, via
  /// [categoriaIds], na categoria).
  final String? textoLivre;

  /// Categorias cujo nome corresponde ao texto procurado.
  final List<String> categoriaIds;

  /// Filtro por categoria escolhido pelo cliente (`null` = todas).
  final String? categoriaId;

  /// Prestadores que atendem em pelo menos uma zona deste município.
  final String? municipio;

  /// Prestadores que atendem nesta zona (enquanto não houver mapa, é assim
  /// que se filtra por proximidade).
  final String? zonaId;
  final bool verificados;
  final double? avaliacaoMinima;
  final OrdemProcura ordem;
  final int limite;

  @override
  bool operator ==(Object other) =>
      other is CriteriosProcura &&
      other.textoLivre == textoLivre &&
      listEquals(other.categoriaIds, categoriaIds) &&
      other.categoriaId == categoriaId &&
      other.municipio == municipio &&
      other.zonaId == zonaId &&
      other.verificados == verificados &&
      other.avaliacaoMinima == avaliacaoMinima &&
      other.ordem == ordem &&
      other.limite == limite;

  @override
  int get hashCode => Object.hash(
    textoLivre,
    Object.hashAll(categoriaIds),
    categoriaId,
    municipio,
    zonaId,
    verificados,
    avaliacaoMinima,
    ordem,
    limite,
  );
}

class ProcuraRepositorio {
  ProcuraRepositorio(this._cliente);

  final SupabaseClient _cliente;

  static const _campos =
      'perfil_id, titulo, categoria_id, bio, anos_experiencia, verificado, '
      'avaliacao_media, total_avaliacoes, servicos_feitos, pct_recomenda, '
      // Há mais de uma relação entre prestadores e perfis (ex.: favoritos);
      // esta é a do dono do registo.
      'perfis!prestadores_perfil_id_fkey(nome, foto), '
      'categorias(nome), '
      'prestador_zonas(zonas(nome)), '
      'precos_prestador(servico_id, valor, servicos(nome)), '
      'servicos_proprios(nome, valor)';

  /// Prestadores visíveis que cumprem os [criterios].
  ///
  /// A visibilidade (aprovado, com assinatura válida) é decidida pela RLS;
  /// aqui não se filtra por `estado` nem por assinatura, para as duas regras
  /// nunca divergirem.
  Future<List<PrestadorPublicoModelo>> procurar(CriteriosProcura criterios) =>
      executarTraduzido(() async {
        // Os filtros por zona e município vão em embeds próprios, com alias:
        // um `!inner` no embed das zonas cortaria a lista que o cartão
        // mostra às zonas filtradas.
        final campos = [
          _campos,
          if (criterios.zonaId != null)
            'zona_filtro:prestador_zonas!inner(zona_id)',
          if (criterios.municipio != null)
            'municipio_filtro:prestador_zonas!inner(zonas!inner(municipio))',
        ].join(', ');

        var consulta = _cliente.from('prestadores').select(campos);
        if (criterios.zonaId case final zonaId?) {
          consulta = consulta.eq('zona_filtro.zona_id', zonaId);
        }
        if (criterios.municipio case final municipio?) {
          consulta = consulta.eq('municipio_filtro.zonas.municipio', municipio);
        }
        if (criterios.categoriaId case final categoriaId?) {
          consulta = consulta.eq('categoria_id', categoriaId);
        }
        if (criterios.verificados) consulta = consulta.eq('verificado', true);
        if (criterios.avaliacaoMinima case final minima?) {
          consulta = consulta.gte('avaliacao_media', minima);
        }
        final texto = _textoLimpo(criterios.textoLivre);
        final porNomeOuServico = texto == null
            ? const <String>{}
            : await _prestadoresPorNomeOuServico(texto);
        if (_condicaoTexto(texto, criterios.categoriaIds, porNomeOuServico)
            case final condicao?) {
          consulta = consulta.or(condicao);
        }

        final ordenada = switch (criterios.ordem) {
          OrdemProcura.reputacao =>
            consulta
                .order('avaliacao_media', ascending: false, nullsFirst: false)
                .order('total_avaliacoes', ascending: false)
                .order('servicos_feitos', ascending: false),
          OrdemProcura.servicosFeitos =>
            consulta
                .order('servicos_feitos', ascending: false)
                .order('avaliacao_media', ascending: false, nullsFirst: false),
        };
        final linhas = await ordenada.limit(criterios.limite);
        return linhas.map(_modelo).toList();
      });

  /// Um prestador, para o perfil. `null` se não existir ou a RLS o esconder.
  Future<PrestadorPublicoModelo?> obter(String perfilId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('prestadores')
            .select(_campos)
            .eq('perfil_id', perfilId)
            .maybeSingle();
        return linha == null ? null : _modelo(linha);
      });

  /// Zona do próprio cliente (`perfis.zona_id`), para os destaques "perto de
  /// si". `null` se não tiver.
  Future<String?> zonaDoCliente(String clienteId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('perfis')
            .select('zona_id')
            .eq('id', clienteId)
            .maybeSingle();
        return linha?['zona_id'] as String?;
      });

  PrestadorPublicoModelo _modelo(Map<String, dynamic> linha) {
    final perfil = linha['perfis'] as Map<String, dynamic>?;
    return PrestadorPublicoModelo.fromJson(
      linha,
      fotoUrl: urlFotoPerfil(_cliente, perfil?['foto'] as String?),
    );
  }

  /// Texto seguro para `ilike` e para o filtro `or`, ou `null` se vazio.
  /// Vírgulas, parênteses, asteriscos e `%` partem a sintaxe dos filtros.
  static String? _textoLimpo(String? texto) {
    final limpo = texto?.replaceAll(RegExp(r'[,()*%]'), ' ').trim();
    return limpo == null || limpo.isEmpty ? null : limpo;
  }

  /// `perfil_id` dos prestadores cujo nome, serviço com preço ou serviço
  /// próprio contém [texto]. O filtro `or` não mistura colunas de tabelas
  /// embebidas com as de `prestadores`, por isso estas procuras vão à parte
  /// e entram na condição como `perfil_id.in.(…)`.
  Future<Set<String>> _prestadoresPorNomeOuServico(String texto) async {
    final padrao = '%$texto%';
    final respostas = await Future.wait([
      _cliente
          .from('prestadores')
          .select('perfil_id, perfis!prestadores_perfil_id_fkey!inner(nome)')
          .ilike('perfis.nome', padrao),
      _cliente
          .from('precos_prestador')
          .select('perfil_id:prestador_id, servicos!inner(nome)')
          .ilike('servicos.nome', padrao),
      _cliente
          .from('servicos_proprios')
          .select('perfil_id:prestador_id')
          .ilike('nome', padrao),
    ]);
    return {
      for (final linhas in respostas)
        for (final l in linhas) '${l['perfil_id']}',
    };
  }

  /// `or=(titulo.ilike.*x*,bio.ilike.*x*,categoria_id.in.(…),
  /// perfil_id.in.(…))`, ou `null` se não há texto nem categorias.
  static String? _condicaoTexto(
    String? texto,
    List<String> categoriaIds,
    Set<String> perfilIds,
  ) {
    final partes = [
      if (texto != null) ...['titulo.ilike.*$texto*', 'bio.ilike.*$texto*'],
      if (categoriaIds.isNotEmpty)
        'categoria_id.in.(${categoriaIds.join(',')})',
      if (perfilIds.isNotEmpty) 'perfil_id.in.(${perfilIds.join(',')})',
    ];
    return partes.isEmpty ? null : partes.join(',');
  }
}
