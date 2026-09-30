import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/controladores/catalogo_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/categoria_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/zona_modelo.dart';
import 'package:biscate_facil/funcionalidades/cliente/apresentacao/controladores/perfil_prestador_controlador.dart';
import 'package:biscate_facil/funcionalidades/cliente/apresentacao/controladores/procura_controlador.dart';
import 'package:biscate_facil/funcionalidades/cliente/apresentacao/ecras/ecra_perfil_prestador.dart';
import 'package:biscate_facil/funcionalidades/cliente/apresentacao/ecras/ecra_pesquisa.dart';
import 'package:biscate_facil/funcionalidades/cliente/dados/modelos/prestador_publico_modelo.dart';
import 'package:biscate_facil/funcionalidades/cliente/dados/repositorios/favoritos_repositorio.dart';
import 'package:biscate_facil/funcionalidades/cliente/dados/repositorios/procura_repositorio.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

const _categorias = [
  CategoriaModelo(id: 'electricidade', nome: 'Electricidade'),
  CategoriaModelo(id: 'canalizacao', nome: 'Canalização'),
  CategoriaModelo(id: 'pintura', nome: 'Pintura'),
];

const _carlos = PrestadorPublicoModelo(
  perfilId: 'carlos',
  nome: 'Carlos Mabunda',
  fotoUrl: null,
  categoria: 'Electricidade',
  zonas: ['Fomento', 'Machava'],
  verificado: true,
  avaliacaoMedia: 4.8,
  totalAvaliacoes: 62,
  servicosFeitos: 148,
  pctRecomenda: 96,
  bio: 'Instalações e reparações eléctricas.',
  anosExperiencia: 8,
  precos: [
    PrecoPublicoModelo(servico: 'Instalação', valor: 1500),
    PrecoPublicoModelo(servico: 'Reparação', valor: null),
  ],
);

const _helio = PrestadorPublicoModelo(
  perfilId: 'helio',
  nome: 'Hélio Cossa',
  fotoUrl: null,
  categoria: 'Canalização',
  zonas: ['Maxaquene'],
  avaliacaoMedia: 4.6,
  totalAvaliacoes: 12,
  servicosFeitos: 40,
  precos: [PrecoPublicoModelo(servico: 'Desentupir', valor: 400)],
);

const _novo = PrestadorPublicoModelo(
  perfilId: 'novo',
  nome: 'Isac Langa',
  fotoUrl: null,
  categoria: 'Electricidade',
);

class _ProcuraFalsa extends ProcuraRepositorio {
  _ProcuraFalsa() : super(_clienteFalso);

  final pedidos = <CriteriosProcura>[];

  @override
  Future<List<PrestadorPublicoModelo>> procurar(
    CriteriosProcura criterios,
  ) async {
    pedidos.add(criterios);
    // A base devolve já ordenado por reputação; o mais barato vem em 2.º.
    return const [_carlos, _helio, _novo];
  }

  @override
  Future<PrestadorPublicoModelo?> obter(String perfilId) async =>
      perfilId == 'carlos' ? _carlos : null;

  @override
  Future<String?> zonaDoCliente(String clienteId) async => 'fomento';
}

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'cliente-1';
}

class _FavoritosFalsos extends FavoritosRepositorio {
  _FavoritosFalsos() : super(_clienteFalso);

  bool recusar = false;

  @override
  Future<bool> eFavorito(String clienteId, String prestadorId) async => false;

  @override
  Future<void> adicionar(String clienteId, String prestadorId) async {
    if (recusar) throw const FalhaApp('Não tem permissão para fazer isto.');
  }

  @override
  Future<void> remover(String clienteId, String prestadorId) async {}
}

List<Override> _substituicoes(_ProcuraFalsa procura, _FavoritosFalsos favs) => [
  procuraRepositorioProvider.overrideWithValue(procura),
  favoritosRepositorioProvider.overrideWithValue(favs),
  autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
  categoriasProvider.overrideWith((ref) async => _categorias),
  zonasProvider.overrideWith(
    (ref) async => const [
      ZonaModelo(id: 'fomento', nome: 'Fomento', municipio: 'Matola'),
    ],
  ),
];

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

  group('texto procurado → categorias', () {
    test('radical comum, sem acentos nem maiúsculas', () {
      expect(categoriasCorrespondentes(_categorias, 'Electricista'), [
        'electricidade',
      ]);
      expect(categoriasCorrespondentes(_categorias, 'canalizador'), [
        'canalizacao',
      ]);
      expect(categoriasCorrespondentes(_categorias, 'PINTOR'), ['pintura']);
      expect(categoriasCorrespondentes(_categorias, 'can'), ['canalizacao']);
      expect(categoriasCorrespondentes(_categorias, 'jardim'), isEmpty);
      expect(categoriasCorrespondentes(_categorias, ''), isEmpty);
    });
  });

  test(
    'critérios: reputação por omissão, zona por id, sem preço na ordem',
    () async {
      final procura = _ProcuraFalsa();
      final container = ProviderContainer(
        overrides: _substituicoes(procura, _FavoritosFalsos()),
      );
      addTearDown(container.dispose);
      final filtro = container.read(procuraControladorProvider('Electricista'));
      final sub = container.listen(
        resultadosProcuraProvider(filtro),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(resultadosProcuraProvider(filtro).future);

      final pedido = procura.pedidos.single;
      expect(pedido.ordem, OrdemProcura.reputacao);
      expect(pedido.categoriaIds, ['electricidade']);
      expect(pedido.verificados, isFalse);
      expect(OrdemProcura.values, isNot(contains('preco')));

      container
          .read(procuraControladorProvider('Electricista').notifier)
          .escolherZona(
            const ZonaModelo(
              id: 'fomento',
              nome: 'Fomento',
              municipio: 'Matola',
            ),
          );
      final comZona = container.read(
        procuraControladorProvider('Electricista'),
      );
      await container.read(resultadosProcuraProvider(comZona).future);
      expect(procura.pedidos.last.zonaId, 'fomento');
    },
  );

  test('"Até 1 000 MT" filtra sem mudar a ordem da reputação', () async {
    final container = ProviderContainer(
      overrides: _substituicoes(_ProcuraFalsa(), _FavoritosFalsos()),
    );
    addTearDown(container.dispose);
    const filtro = FiltroProcura(ate1000: true);
    final sub = container.listen(resultadosProcuraProvider(filtro), (_, _) {});
    addTearDown(sub.close);
    final lista = await container.read(
      resultadosProcuraProvider(filtro).future,
    );
    // Carlos pede 1 500; Isac não indicou preços; fica só o Hélio.
    expect(lista.map((p) => p.perfilId), ['helio']);
  });

  test('favorito muda logo e volta atrás se a base recusar', () async {
    final favs = _FavoritosFalsos()..recusar = true;
    final container = ProviderContainer(
      overrides: _substituicoes(_ProcuraFalsa(), favs),
    );
    addTearDown(container.dispose);
    final sub = container.listen(favoritoProvider('carlos'), (_, _) {});
    addTearDown(sub.close);
    await container.read(favoritoProvider('carlos').future);

    final erro = await container
        .read(favoritoProvider('carlos').notifier)
        .alternar();
    expect(erro, 'Não tem permissão para fazer isto.');
    expect(container.read(favoritoProvider('carlos')).value, isFalse);
  });

  testWidgets('pesquisa e perfil com dados cabem a 360×760', (testador) async {
    testador.view.physicalSize = const Size(360, 760);
    testador.view.devicePixelRatio = 1;
    addTearDown(testador.view.reset);
    await testador.pumpWidget(
      ProviderScope(
        overrides: _substituicoes(_ProcuraFalsa(), _FavoritosFalsos()),
        child: MaterialApp(theme: construirTema(), home: const EcraPesquisa()),
      ),
    );
    await testador.pumpAndSettle();
    expect(find.text('3 prestadores'), findsOneWidget);
    expect(find.text('Carlos Mabunda'), findsOneWidget);
    expect(find.text('desde 1 500 MT'), findsOneWidget);
    expect(find.text('Novo'), findsOneWidget, reason: 'sem avaliações');
    expect(find.text('Mais baratos'), findsNothing);

    await testador.tap(find.text('Carlos Mabunda'));
    await testador.pumpAndSettle();
    expect(find.byType(EcraPerfilPrestador), findsOneWidget);
    expect(
      find.textContaining('Identidade verificada', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('Sob orçamento'), findsOneWidget);
    await testador.drag(find.byType(ListView).last, const Offset(0, -600));
    await testador.pumpAndSettle();
    expect(testador.takeException(), isNull);
  });
}
