import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../modelos/categoria_modelo.dart';
import '../modelos/servico_modelo.dart';
import '../modelos/zona_modelo.dart';

final catalogoRepositorioProvider = Provider<CatalogoRepositorio>(
  (ref) => CatalogoRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// Categorias, serviços e zonas. Só leitura: estas tabelas são do
/// administrador e a app nunca escreve nelas.
class CatalogoRepositorio {
  CatalogoRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<List<CategoriaModelo>> listarCategorias() =>
      executarTraduzido(() async {
        final linhas = await _cliente
            .from('categorias')
            .select('id, nome, icone, descricao')
            .eq('activa', true)
            .order('ordem')
            .order('nome');
        return linhas.map(CategoriaModelo.fromJson).toList();
      });

  // Atenção: em `servicos` a coluna é `activo`; em `categorias` e `zonas` é
  // `activa`.
  Future<List<ServicoModelo>> listarServicos() => executarTraduzido(() async {
    final linhas = await _cliente
        .from('servicos')
        .select('id, nome, categoria_id')
        .eq('activo', true)
        .order('ordem')
        .order('nome');
    return linhas.map(ServicoModelo.fromJson).toList();
  });

  Future<List<ZonaModelo>> listarZonas() => executarTraduzido(() async {
    final linhas = await _cliente
        .from('zonas')
        .select('id, nome, municipio')
        .eq('activa', true)
        .order('municipio')
        .order('nome');
    return linhas.map(ZonaModelo.fromJson).toList();
  });
}
