import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../catalogo/apresentacao/controladores/catalogo_controlador.dart';
import '../../../catalogo/dados/modelos/categoria_modelo.dart';
import '../../../catalogo/dados/modelos/zona_modelo.dart';
import '../../dados/modelos/prestador_publico_modelo.dart';
import '../../dados/repositorios/procura_repositorio.dart';

/// O que o cliente escolheu no ecrã de pesquisa.
@immutable
class FiltroProcura {
  const FiltroProcura({
    this.texto = '',
    this.categoriaId,
    this.categoriaNome,
    this.municipio,
    this.zonaId,
    this.zonaNome,
    this.ate1000 = false,
    this.minimo4 = false,
    this.verificados = false,
    this.ordem = OrdemProcura.reputacao,
  });

  final String texto;

  /// `null` = todas as categorias.
  final String? categoriaId;
  final String? categoriaNome;

  /// `null` = todos os municípios.
  final String? municipio;

  /// `null` = todas as zonas do município.
  final String? zonaId;
  final String? zonaNome;
  final bool ate1000;
  final bool minimo4;
  final bool verificados;
  final OrdemProcura ordem;

  static const limitePreco = 1000;

  FiltroProcura copiarCom({
    String? texto,
    CategoriaModelo? categoria,
    bool limparCategoria = false,
    String? municipio,
    bool limparMunicipio = false,
    ZonaModelo? zona,
    bool limparZona = false,
    bool? ate1000,
    bool? minimo4,
    bool? verificados,
    OrdemProcura? ordem,
  }) => FiltroProcura(
    texto: texto ?? this.texto,
    categoriaId: limparCategoria ? null : (categoria?.id ?? categoriaId),
    categoriaNome: limparCategoria ? null : (categoria?.nome ?? categoriaNome),
    municipio: limparMunicipio ? null : (municipio ?? this.municipio),
    zonaId: limparZona ? null : (zona?.id ?? zonaId),
    zonaNome: limparZona ? null : (zona?.nome ?? zonaNome),
    ate1000: ate1000 ?? this.ate1000,
    minimo4: minimo4 ?? this.minimo4,
    verificados: verificados ?? this.verificados,
    ordem: ordem ?? this.ordem,
  );

  @override
  bool operator ==(Object other) =>
      other is FiltroProcura &&
      other.texto == texto &&
      other.categoriaId == categoriaId &&
      other.municipio == municipio &&
      other.zonaId == zonaId &&
      other.ate1000 == ate1000 &&
      other.minimo4 == minimo4 &&
      other.verificados == verificados &&
      other.ordem == ordem;

  @override
  int get hashCode => Object.hash(
    texto,
    categoriaId,
    municipio,
    zonaId,
    ate1000,
    minimo4,
    verificados,
    ordem,
  );
}

/// Filtros do ecrã de pesquisa. A família é pela consulta com que o ecrã
/// abriu (o início abre a pesquisa já com uma categoria).
final procuraControladorProvider = NotifierProvider.autoDispose
    .family<ProcuraControlador, FiltroProcura, String>(ProcuraControlador.new);

class ProcuraControlador
    extends AutoDisposeFamilyNotifier<FiltroProcura, String> {
  /// Espera depois da última tecla antes de procurar.
  static const esperaTexto = Duration(milliseconds: 400);

  Timer? _espera;

  @override
  FiltroProcura build(String consultaInicial) {
    ref.onDispose(() => _espera?.cancel());
    return FiltroProcura(texto: consultaInicial.trim());
  }

  void definirTexto(String texto) {
    _espera?.cancel();
    _espera = Timer(
      esperaTexto,
      () => state = state.copiarCom(texto: texto.trim()),
    );
  }

  void limparTexto() {
    _espera?.cancel();
    state = state.copiarCom(texto: '');
  }

  void escolherCategoria(CategoriaModelo? categoria) => state = state.copiarCom(
    categoria: categoria,
    limparCategoria: categoria == null,
  );

  /// Mudar de município limpa a zona, que podia ser de outro.
  void escolherMunicipio(String? municipio) => state = state.copiarCom(
    municipio: municipio,
    limparMunicipio: municipio == null,
    limparZona: true,
  );

  void escolherZona(ZonaModelo? zona) =>
      state = state.copiarCom(zona: zona, limparZona: zona == null);

  void alternarAte1000() => state = state.copiarCom(ate1000: !state.ate1000);
  void alternarMinimo4() => state = state.copiarCom(minimo4: !state.minimo4);
  void alternarVerificados() =>
      state = state.copiarCom(verificados: !state.verificados);
  void ordenar(OrdemProcura ordem) => state = state.copiarCom(ordem: ordem);
}

/// Resultados de um filtro. "Tentar de novo" é
/// `ref.invalidate(resultadosProcuraProvider(filtro))`.
final resultadosProcuraProvider = FutureProvider.autoDispose
    .family<List<PrestadorPublicoModelo>, FiltroProcura>((ref, filtro) async {
      // Sem o catálogo, a procura faz-se só no título e na descrição.
      final categorias = filtro.texto.isEmpty
          ? const <CategoriaModelo>[]
          : await ref
                .watch(categoriasProvider.future)
                .catchError((_) => const <CategoriaModelo>[]);
      final prestadores = await ref
          .watch(procuraRepositorioProvider)
          .procurar(
            CriteriosProcura(
              textoLivre: filtro.texto.isEmpty ? null : filtro.texto,
              categoriaIds: categoriasCorrespondentes(categorias, filtro.texto),
              categoriaId: filtro.categoriaId,
              municipio: filtro.municipio,
              zonaId: filtro.zonaId,
              verificados: filtro.verificados,
              avaliacaoMinima: filtro.minimo4 ? 4 : null,
              ordem: filtro.ordem,
            ),
          );
      if (!filtro.ate1000) return prestadores;
      // Filtra, não ordena: a ordem continua a ser a da reputação.
      return [
        for (final p in prestadores)
          if (p.desde case final desde? when desde <= FiltroProcura.limitePreco)
            p,
      ];
    });

/// Prestadores em destaque no início: os de melhor reputação que atendem na
/// zona do cliente (ou em qualquer zona, se o perfil não tiver zona).
final destaquesProvider =
    FutureProvider.autoDispose<List<PrestadorPublicoModelo>>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final repositorio = ref.watch(procuraRepositorioProvider);
      final clienteId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      final zonaId = clienteId == null
          ? null
          : await repositorio.zonaDoCliente(clienteId);
      return repositorio.procurar(CriteriosProcura(zonaId: zonaId, limite: 5));
    });

// ── Regras de texto ────────────────────────────────────────────────────────

/// Categorias do catálogo que correspondem ao que o cliente escreveu.
///
/// Sem acentos nem maiúsculas, e por radical comum: "electricista" encontra
/// "Electricidade", "canalizador" encontra "Canalização". Um radical comum
/// de pelo menos [radicalMinimo] letras chega.
List<String> categoriasCorrespondentes(
  List<CategoriaModelo> categorias,
  String texto,
) {
  final procurado = semAcentos(texto.trim().toLowerCase());
  if (procurado.length < radicalMinimo) {
    return procurado.isEmpty
        ? const []
        : [
            for (final c in categorias)
              if (semAcentos(c.nome.toLowerCase()).startsWith(procurado)) c.id,
          ];
  }
  return [
    for (final c in categorias)
      if (_prefixoComum(semAcentos(c.nome.toLowerCase()), procurado) >=
          radicalMinimo)
        c.id,
  ];
}

const radicalMinimo = 4;

int _prefixoComum(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  return i;
}

String semAcentos(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final letra in texto.split('')) {
    final i = de.indexOf(letra);
    saida.write(i < 0 ? letra : para[i]);
  }
  return saida.toString();
}

// ── Apresentação ───────────────────────────────────────────────────────────

/// "4.8", ou `null` sem avaliações (o cartão mostra "Novo").
String? textoAvaliacao(PrestadorPublicoModelo p) =>
    p.avaliacaoMedia?.toStringAsFixed(1);

/// "desde 500 MT", "sob orçamento", ou `null` se não indicou preços.
String? textoDesde(PrestadorPublicoModelo p) {
  if (p.desde case final desde?) return 'desde ${formatarMt(desde)} MT';
  return p.precos.isEmpty ? null : 'sob orçamento';
}

String textoPreco(int? valor) =>
    valor == null ? 'Sob orçamento' : '${formatarMt(valor)} MT';
