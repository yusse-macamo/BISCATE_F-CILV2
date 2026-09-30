import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/ecras/ecra_catalogo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/controladores/catalogo_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/categoria_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/servico_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/zona_modelo.dart';
import 'package:biscate_facil/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrega as fontes reais para que as medidas de texto correspondam ao app.
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

/// A app sem Supabase: arranca sem sessão e com catálogo fixo.
Widget _app() => ProviderScope(
  overrides: [
    destinoInicialProvider.overrideWith(
      (ref) async => DestinoInicial.boasVindas,
    ),
    categoriasProvider.overrideWith(
      (ref) async => const [
        CategoriaModelo(id: 'canalizacao', nome: 'Canalização'),
        CategoriaModelo(id: 'electricidade', nome: 'Electricidade'),
      ],
    ),
    servicosProvider.overrideWith(
      (ref) async => const [
        ServicoModelo(
          id: 'desentupimento',
          nome: 'Desentupimento',
          categoriaId: 'canalizacao',
        ),
      ],
    ),
    zonasProvider.overrideWith(
      (ref) async => const [
        ZonaModelo(id: 'fomento', nome: 'Fomento', municipio: 'Matola'),
        ZonaModelo(id: 'machava', nome: 'Machava', municipio: 'Matola'),
      ],
    ),
  ],
  child: const AppBiscateFacil(),
);

void main() {
  setUpAll(_carregarFontes);

  testWidgets('Boas-vindas abre o login', (testador) async {
    await testador.pumpWidget(_app());
    await testador.pumpAndSettle();
    expect(find.text('O profissional certo, perto de si.'), findsOneWidget);
    await testador.tap(find.text('Entrar'));
    await testador.pumpAndSettle();
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });

  testWidgets('As 20 telas renderizam sem overflow a 360×760', (
    testador,
  ) async {
    testador.view.physicalSize = const Size(360, 760);
    testador.view.devicePixelRatio = 1;
    addTearDown(testador.view.reset);
    await testador.pumpWidget(_app());
    await testador.pumpAndSettle();
    final navegador = testador.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navegador.push(MaterialPageRoute(builder: (_) => const EcraCatalogo()));
    await testador.pumpAndSettle();
    for (var n = 1; n <= 20; n++) {
      final rotulo = find.text(n.toString().padLeft(2, '0'));
      await testador.scrollUntilVisible(
        rotulo,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      await testador.tap(rotulo);
      await testador.pumpAndSettle();
      expect(testador.takeException(), isNull, reason: 'tela $n');
      navegador.pop();
      await testador.pumpAndSettle();
    }
  });
}
