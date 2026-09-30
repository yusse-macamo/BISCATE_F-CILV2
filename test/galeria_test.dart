import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/portfolio_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/ecras/ecra_portfolio.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/portfolio_repositorio.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:biscate_facil/nucleo/utilitarios/imagens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

FotoPortfolioModelo _foto(int i, {String? legenda}) => FotoPortfolioModelo(
  id: 'f$i',
  caminho: 'prestador-1/portfolio_$i.jpg',
  url: null,
  legenda: legenda,
  ordem: i,
);

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'prestador-1';
}

class _PortfolioFalso extends PortfolioRepositorio {
  _PortfolioFalso(this.fotos) : super(_clienteFalso);

  final List<FotoPortfolioModelo> fotos;
  final adicionadas = <({int ordem, String? legenda})>[];
  final removidas = <String>[];

  @override
  Future<List<FotoPortfolioModelo>> listar(String prestadorId) async => fotos;

  @override
  Future<void> adicionarFoto({
    required String prestadorId,
    required Uint8List bytes,
    required int ordem,
    String? legenda,
  }) async => adicionadas.add((ordem: ordem, legenda: legenda));

  @override
  Future<void> remover(FotoPortfolioModelo foto) async =>
      removidas.add(foto.caminho);
}

class _CompressorFalso extends CompressorImagem {
  int chamadas = 0;

  @override
  Future<Uint8List> comprimir(Uint8List original) async {
    chamadas++;
    return original;
  }
}

final _imagem = ImagemEscolhida(
  nome: 'obra.jpg',
  bytes: Uint8List.fromList(const [1, 2, 3]),
);

(ProviderContainer, _PortfolioFalso, _CompressorFalso) _preparar(
  List<FotoPortfolioModelo> fotos,
) {
  final repo = _PortfolioFalso(fotos);
  final compressor = _CompressorFalso();
  final container = ProviderContainer(
    overrides: [
      autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
      portfolioRepositorioProvider.overrideWithValue(repo),
      compressorImagemProvider.overrideWithValue(compressor),
      sessaoProvider.overrideWith((ref) => Stream.value(null)),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(galeriaControladorProvider, (_, _) {});
  addTearDown(sub.close);
  return (container, repo, compressor);
}

Future<void> _carregarFontes() async {
  Future<ByteData> ler(String f) async =>
      ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(ler('Manrope-$w.ttf'));
  }
  await manrope.load();
  await (FontLoader(
    'JetBrainsMono',
  )..addFont(ler('JetBrainsMono-400.ttf'))).load();
}

void main() {
  setUpAll(_carregarFontes);

  test('publica comprimida, no fim, com legenda aparada', () async {
    final actuais = [_foto(1), _foto(4), _foto(2)];
    final (container, repo, compressor) = _preparar(actuais);
    final c = container.read(galeriaControladorProvider.notifier);

    expect(
      await c.publicar(_imagem, actuais: actuais, legenda: '  Quadro novo  '),
      isNull,
    );
    expect(await c.publicar(_imagem, actuais: actuais, legenda: '   '), isNull);
    expect(compressor.chamadas, 2);
    expect(repo.adicionadas, [
      (ordem: 5, legenda: 'Quadro novo'),
      (ordem: 5, legenda: null),
    ]);
  });

  test('com 10 fotografias recusa a 11.ª sem enviar nada', () async {
    final actuais = [for (var i = 1; i <= 10; i++) _foto(i)];
    final (container, repo, compressor) = _preparar(actuais);
    final c = container.read(galeriaControladorProvider.notifier);

    final erro = await c.publicar(_imagem, actuais: actuais);
    expect(erro, contains('máximo de 10'));
    expect(compressor.chamadas, 0);
    expect(repo.adicionadas, isEmpty);
  });

  test('remover passa a fotografia ao repositório', () async {
    final (container, repo, _) = _preparar([_foto(1)]);
    final c = container.read(galeriaControladorProvider.notifier);
    expect(await c.remover(_foto(1)), isNull);
    expect(repo.removidas, ['prestador-1/portfolio_1.jpg']);
  });

  Future<void> abrir(WidgetTester t, List<FotoPortfolioModelo> fotos) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          autenticacaoRepositorioProvider.overrideWithValue(
            _AutenticacaoFalsa(),
          ),
          portfolioRepositorioProvider.overrideWithValue(
            _PortfolioFalso(fotos),
          ),
          sessaoProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(theme: construirTema(), home: const EcraPortfolio()),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('galeria com legendas cabe a 360×760', (t) async {
    await abrir(t, [
      _foto(1, legenda: 'Quadro eléctrico, antes e depois'),
      _foto(2),
    ]);
    expect(find.text('2 de 10 fotografias'), findsOneWidget);
    expect(find.text('Acrescentar'), findsOneWidget);
    expect(find.text('Quadro eléctrico, antes e depois'), findsOneWidget);
    expect(find.text('✕'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('com 10 fotografias não mostra "Acrescentar"', (t) async {
    await abrir(t, [for (var i = 1; i <= 10; i++) _foto(i)]);
    expect(find.text('10 de 10 fotografias'), findsOneWidget);
    expect(find.text('Acrescentar'), findsNothing);
  });

  testWidgets('sem fotografias mostra o estado vazio', (t) async {
    await abrir(t, const []);
    expect(find.textContaining('Ainda não publicou trabalhos'), findsOneWidget);
    expect(find.text('Acrescentar'), findsOneWidget);
  });
}
