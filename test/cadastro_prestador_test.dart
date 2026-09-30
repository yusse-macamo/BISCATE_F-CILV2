import 'dart:io';

import 'package:biscate_facil/funcionalidades/autenticacao/apresentacao/controladores/sessao_controlador.dart';
import 'package:biscate_facil/funcionalidades/autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import 'package:biscate_facil/funcionalidades/catalogo/apresentacao/controladores/catalogo_controlador.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/categoria_modelo.dart';
import 'package:biscate_facil/funcionalidades/catalogo/dados/modelos/zona_modelo.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/cadastro_prestador_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/cadastro_prestador_estado.dart';
import 'package:biscate_facil/funcionalidades/prestador/apresentacao/ecras/ecra_cadastro_prestador.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/modelos/novo_prestador_modelo.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/repositorios/prestador_repositorio.dart';
import 'package:biscate_facil/nucleo/dados/excepcoes.dart';
import 'package:biscate_facil/nucleo/tema/tema_app.dart';
import 'package:biscate_facil/nucleo/utilitarios/imagens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PNG de 1×1, para as miniaturas descodificarem no teste.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, //
  120, 156, 99, 248, 15, 4, 0, 9, 251, 3, 253, 227, 85, 242, 156, 0, 0, 0, //
  0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

final _clienteFalso = SupabaseClient('http://localhost', 'chave-falsa');

class _AutenticacaoFalsa extends AutenticacaoRepositorio {
  _AutenticacaoFalsa() : super(_clienteFalso);

  @override
  String? get utilizadorId => 'utilizador-1';
}

class _PrestadorFalso extends PrestadorRepositorio {
  _PrestadorFalso() : super(_clienteFalso);

  final carregamentos = <String>[];
  final registos = <Map<String, dynamic>>[];
  final documentos = <Map<String, String>>[];
  final fotosNoPerfil = <String>[];
  var zonasAssociadas = <String>{};

  /// Se não for null, a primeira tentativa de registar falha.
  String? falharRegistoUmaVez;

  @override
  Future<String> carregarImagem({
    required String bucket,
    required String perfilId,
    required String tipo,
    required Uint8List bytes,
  }) async {
    // Como o real: nome com carimbo temporal, devolvido a quem chamou.
    final caminho = '$perfilId/${tipo}_${carregamentos.length + 1000}.jpg';
    carregamentos.add('$bucket/$caminho');
    return caminho;
  }

  @override
  Future<void> gravarFotoPerfil({
    required String perfilId,
    required String caminho,
  }) async => fotosNoPerfil.add('$perfilId:$caminho');

  @override
  Future<void> registarDocumentos({
    required String perfilId,
    required Map<String, String> caminhosPorTipo,
  }) async => documentos.add(caminhosPorTipo);

  @override
  Future<void> registar(NovoPrestadorModelo prestador) async {
    final erro = falharRegistoUmaVez;
    if (erro != null) {
      falharRegistoUmaVez = null;
      throw FalhaApp(erro);
    }
    registos.add(prestador.toJson());
  }

  @override
  Future<void> associarZonas({
    required String perfilId,
    required Set<String> zonaIds,
  }) async => zonasAssociadas = zonaIds;
}

class _SeletorFalso extends SeletorImagem {
  @override
  Future<ImagemEscolhida?> escolher(OrigemImagem origem) async =>
      ImagemEscolhida(nome: 'IMG_0001.jpg', bytes: _png);
}

class _CompressorFalso extends CompressorImagem {
  int chamadas = 0;

  @override
  Future<Uint8List> comprimir(Uint8List original) async {
    chamadas++;
    return original;
  }
}

List<Override> _substituicoes(
  _PrestadorFalso prestador,
  _CompressorFalso compressor,
) => [
  autenticacaoRepositorioProvider.overrideWithValue(_AutenticacaoFalsa()),
  prestadorRepositorioProvider.overrideWithValue(prestador),
  seletorImagemProvider.overrideWithValue(_SeletorFalso()),
  compressorImagemProvider.overrideWithValue(compressor),
  destinoInicialProvider.overrideWith((ref) async => DestinoInicial.cliente),
  categoriasProvider.overrideWith(
    (ref) async => const [
      CategoriaModelo(id: 'electricidade', nome: 'Electricidade'),
      CategoriaModelo(id: 'canalizacao', nome: 'Canalização'),
    ],
  ),
  zonasProvider.overrideWith(
    (ref) async => const [
      ZonaModelo(id: 'fomento', nome: 'Fomento', municipio: 'Matola'),
      ZonaModelo(id: 'machava', nome: 'Machava', municipio: 'Matola'),
      ZonaModelo(id: 'polana', nome: 'Polana', municipio: 'Maputo'),
    ],
  ),
];

Future<void> _preencher(CadastroPrestadorControlador c) async {
  c.escolherCategoria('electricidade');
  c.definirAnos('8');
  expect(c.avancar(), isTrue);
  c.alternarZona('fomento');
  c.alternarZona('machava');
  expect(c.avancar(), isTrue);
  await c.escolherDocumento(TipoDocumento.fotoPerfil, OrigemImagem.galeria);
  await c.escolherDocumento(TipoDocumento.biFrente, OrigemImagem.camara);
}

Future<void> _esperarEnvio(ProviderContainer container) async {
  while (container.read(cadastroPrestadorControladorProvider).aEnviar) {
    await Future<void>.delayed(Duration.zero);
  }
}

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

void main() {
  setUpAll(_carregarFontes);

  test('não avança sem serviço, zonas e documentos obrigatórios', () {
    final container = ProviderContainer(
      overrides: _substituicoes(_PrestadorFalso(), _CompressorFalso()),
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      cadastroPrestadorControladorProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    final c = container.read(cadastroPrestadorControladorProvider.notifier);

    c.definirAnos('200');
    expect(c.avancar(), isFalse);
    final erros = container.read(cadastroPrestadorControladorProvider).erros;
    expect(erros.keys, containsAll(['categoria', 'anos']));

    c.escolherCategoria('electricidade');
    c.definirAnos('');
    expect(c.avancar(), isTrue);
    expect(c.avancar(), isFalse, reason: 'sem zonas');
    c.alternarZona('fomento');
    expect(c.avancar(), isTrue);
    expect(c.avancar(), isFalse, reason: 'sem documentos');
    expect(
      container.read(cadastroPrestadorControladorProvider).erros['documentos'],
      'Faltam a foto de perfil e a frente do BI.',
    );
  });

  test(
    'envia, e ao repetir retoma sem voltar a comprimir nem a carregar',
    () async {
      final prestador = _PrestadorFalso()..falharRegistoUmaVez = 'Sem ligação.';
      final compressor = _CompressorFalso();
      final container = ProviderContainer(
        overrides: _substituicoes(prestador, compressor),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        cadastroPrestadorControladorProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      final c = container.read(cadastroPrestadorControladorProvider.notifier);

      await _preencher(c);
      expect(c.avancar(), isTrue);
      await _esperarEnvio(container);

      var estado = container.read(cadastroPrestadorControladorProvider);
      expect(estado.erroEnvio, 'Sem ligação.');
      expect(estado.etapaActual, EtapaEnvio.registo);
      expect(estado.enviado, isFalse);
      expect(prestador.carregamentos, [
        'publico/utilizador-1/perfil_1000.jpg',
        'documentos/utilizador-1/bi_frente_1001.jpg',
      ]);
      expect(compressor.chamadas, 2);
      expect(c.recuar(), isTrue, reason: 'ainda nada gravado na tabela');
      expect(c.avancar(), isTrue);
      await _esperarEnvio(container);

      estado = container.read(cadastroPrestadorControladorProvider);
      expect(estado.enviado, isTrue);
      expect(estado.erroEnvio, isNull);
      expect(compressor.chamadas, 2, reason: 'não volta a comprimir');
      expect(
        prestador.carregamentos,
        hasLength(2),
        reason: 'não volta a carregar',
      );
      expect(prestador.zonasAssociadas, {'fomento', 'machava'});
      // Sem bio escrita, `bio` não vai: vale o valor por omissão da tabela.
      expect(prestador.registos.single, {
        'perfil_id': 'utilizador-1',
        'categoria_id': 'electricidade',
        'anos_experiencia': 8,
      });
      expect(
        prestador.registos.single.keys.toSet().difference(const {
          'perfil_id',
          'categoria_id',
          'titulo',
          'bio',
          'anos_experiencia',
          'capa',
          'raio_km',
        }),
        isEmpty,
        reason: 'só as colunas que a app pode escrever',
      );
      // A foto vai para o perfil do próprio, com o caminho devolvido pelo
      // envio (não reconstruído a partir do tipo), uma só vez.
      expect(prestador.fotosNoPerfil, [
        'utilizador-1:utilizador-1/perfil_1000.jpg',
      ]);
      expect(prestador.documentos.single, {
        'bi_frente': 'utilizador-1/bi_frente_1001.jpg',
      });
      expect(
        prestador.registos.single.keys,
        isNot(anyOf(contains('estado'), contains('verificado'))),
      );
    },
  );

  testWidgets('cada passo cabe a 360×760 sem overflow', (testador) async {
    testador.view.physicalSize = const Size(360, 760);
    testador.view.devicePixelRatio = 1;
    addTearDown(testador.view.reset);
    final prestador = _PrestadorFalso()..falharRegistoUmaVez = 'Sem ligação.';
    await testador.pumpWidget(
      ProviderScope(
        overrides: _substituicoes(prestador, _CompressorFalso()),
        child: MaterialApp(
          theme: construirTema(),
          home: const EcraCadastroPrestador(),
        ),
      ),
    );
    await testador.pumpAndSettle();
    expect(find.text('O que faz'), findsOneWidget);

    await testador.tap(find.text('Electricidade'));
    await testador.tap(find.text('Continuar'));
    await testador.pumpAndSettle();
    expect(find.text('Onde atende'), findsOneWidget);

    await testador.tap(find.text('Fomento'));
    await testador.tap(find.text('Continuar'));
    await testador.pumpAndSettle();
    expect(find.text('Documentos'), findsOneWidget);

    await testador.tap(find.text('Enviar cadastro'));
    await testador.pumpAndSettle();
    expect(
      find.text('Faltam a foto de perfil e a frente do BI.'),
      findsOneWidget,
    );

    for (final titulo in ['Foto de perfil', 'BI, frente']) {
      await testador.tap(find.text(titulo));
      await testador.pumpAndSettle();
      await testador.tap(find.text('Escolher da galeria'));
      await testador.pumpAndSettle();
    }
    expect(find.text('IMG_0001.jpg'), findsNWidgets(2));

    await testador.tap(find.text('Enviar cadastro'));
    await testador.pumpAndSettle();
    expect(find.text('O envio parou'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(testador.takeException(), isNull);
  });
}
