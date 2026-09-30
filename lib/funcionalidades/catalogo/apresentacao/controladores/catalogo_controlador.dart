import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../dados/modelos/categoria_modelo.dart';
import '../../dados/modelos/servico_modelo.dart';
import '../../dados/modelos/zona_modelo.dart';
import '../../dados/repositorios/catalogo_repositorio.dart';

// Catálogo carregado uma vez por sessão e guardado em memória: são poucas
// linhas e não mudam durante o uso. Os providers não são autoDispose, por isso
// o resultado fica em cache até mudar o utilizador (o que a RLS deixa ler pode
// depender da sessão) ou até alguém pedir "tentar de novo" com
// `ref.invalidate`.
//
// São três providers separados para que uma tabela com erro não impeça os
// ecrãs que só precisam das outras.

Future<void> _porSessao(Ref ref) =>
    ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));

final categoriasProvider = FutureProvider<List<CategoriaModelo>>((ref) async {
  await _porSessao(ref);
  return ref.watch(catalogoRepositorioProvider).listarCategorias();
});

final servicosProvider = FutureProvider<List<ServicoModelo>>((ref) async {
  await _porSessao(ref);
  return ref.watch(catalogoRepositorioProvider).listarServicos();
});

final zonasProvider = FutureProvider<List<ZonaModelo>>((ref) async {
  await _porSessao(ref);
  return ref.watch(catalogoRepositorioProvider).listarZonas();
});

/// Municípios com pelo menos uma zona, pela ordem em que vêm da base.
List<String> municipiosDe(List<ZonaModelo> zonas) =>
    zonas.map((zona) => zona.municipio).toSet().toList();

List<ZonaModelo> zonasDoMunicipio(List<ZonaModelo> zonas, String? municipio) =>
    zonas.where((zona) => zona.municipio == municipio).toList();

List<ServicoModelo> servicosDaCategoria(
  List<ServicoModelo> servicos,
  String categoriaId,
) => servicos.where((servico) => servico.categoriaId == categoriaId).toList();

/// Atalhos de pesquisa por baixo da caixa de procura no início: os nomes das
/// primeiras categorias, pela ordem da base.
List<String> sugestoesDePesquisa(List<CategoriaModelo> categorias) => [
  for (final categoria in categorias.take(5)) categoria.nome,
];
