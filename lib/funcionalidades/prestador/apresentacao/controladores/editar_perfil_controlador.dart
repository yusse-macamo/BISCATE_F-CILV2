import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/imagens.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/apresentacao/controladores/validacoes.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../cliente/apresentacao/controladores/perfil_prestador_controlador.dart';
import '../../dados/modelos/perfil_editavel_modelo.dart';
import '../../dados/repositorios/prestador_repositorio.dart';
import 'painel_controlador.dart';

/// O perfil do prestador autenticado, como está na base. `null` se não tem
/// registo de prestador.
final perfilEditavelProvider =
    FutureProvider.autoDispose<PerfilEditavelModelo?>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para editar o seu perfil.');
      }
      return ref.watch(prestadorRepositorioProvider).obterPerfilEditavel(id);
    });

@immutable
class EstadoEdicao {
  const EstadoEdicao({
    this.zonas,
    this.erros = const {},
    this.aGuardar = false,
    this.erroGuardar,
  });

  /// Zonas escolhidas no ecrã; `null` enquanto não mexeu (valem as da base).
  final Set<String>? zonas;

  /// `titulo`, `bio`, `anos`, `telefone`, `zonas`.
  final Map<String, String> erros;
  final bool aGuardar;
  final String? erroGuardar;
}

final edicaoPerfilControladorProvider =
    NotifierProvider.autoDispose<EdicaoPerfilControlador, EstadoEdicao>(
      EdicaoPerfilControlador.new,
    );

class EdicaoPerfilControlador extends AutoDisposeNotifier<EstadoEdicao> {
  static const tituloMaximo = 60;
  static const bioMaxima = 500;
  static const maximoAnos = 60;

  @override
  EstadoEdicao build() => const EstadoEdicao();

  void alternarZona(String zonaId, Set<String> daBase) {
    final zonas = {...(state.zonas ?? daBase)};
    if (!zonas.remove(zonaId)) zonas.add(zonaId);
    state = EstadoEdicao(
      zonas: zonas,
      erros: {...state.erros}..remove('zonas'),
    );
  }

  void limparErro(String campo) => state = EstadoEdicao(
    zonas: state.zonas,
    erros: {...state.erros}..remove(campo),
  );

  /// Valida e grava: `prestadores` (título, descrição, experiência),
  /// `perfis.telefone` e a diferença nas zonas. Cada passo pode repetir-se
  /// sem efeitos duplicados. Devolve `true` se ficou tudo gravado.
  Future<bool> guardar({
    required PerfilEditavelModelo original,
    required String titulo,
    required String bio,
    required String anos,
    required String telefone,
  }) async {
    if (state.aGuardar) return false;
    final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (id == null) return false;

    final tituloLimpo = titulo.trim();
    final bioLimpa = bio.trim();
    final anosLimpo = anos.trim();
    final numeroAnos = int.tryParse(anosLimpo);
    final digitos = digitosTelefone(telefone);
    final zonas = state.zonas ?? original.zonaIds;
    final erros = {
      if (tituloLimpo.length > tituloMaximo)
        'titulo': 'Escreva no máximo $tituloMaximo caracteres.',
      if (bioLimpa.length > bioMaxima)
        'bio': 'Escreva no máximo $bioMaxima caracteres.',
      if (anosLimpo.isNotEmpty &&
          (numeroAnos == null || numeroAnos < 0 || numeroAnos > maximoAnos))
        'anos': 'Indique um número de anos entre 0 e $maximoAnos.',
      if (!telefoneValido(digitos))
        'telefone': 'Indique um número móvel válido, ex.: 84 123 4567.',
      if (zonas.isEmpty) 'zonas': 'Escolha pelo menos uma zona onde atende.',
    };
    if (erros.isNotEmpty) {
      state = EstadoEdicao(zonas: state.zonas, erros: erros);
      return false;
    }

    state = EstadoEdicao(zonas: state.zonas, aGuardar: true);
    final repositorio = ref.read(prestadorRepositorioProvider);
    try {
      await repositorio.guardarDadosProfissionais(
        id,
        titulo: tituloLimpo.isEmpty ? null : tituloLimpo,
        bio: bioLimpa.isEmpty ? null : bioLimpa,
        anosExperiencia: anosLimpo.isEmpty ? null : numeroAnos,
      );
      if (digitos != digitosTelefone(original.telefone)) {
        await repositorio.guardarTelefone(id, digitos);
      }
      final novas = zonas.difference(original.zonaIds);
      final tiradas = original.zonaIds.difference(zonas);
      if (novas.isNotEmpty) {
        await repositorio.associarZonas(perfilId: id, zonaIds: novas);
      }
      if (tiradas.isNotEmpty) {
        await repositorio.removerZonas(perfilId: id, zonaIds: tiradas);
      }
      state = const EstadoEdicao();
      ref
        ..invalidate(perfilEditavelProvider)
        ..invalidate(painelProvider)
        ..invalidate(perfilPrestadorProvider(id));
      return true;
    } on FalhaApp catch (falha) {
      state = EstadoEdicao(zonas: state.zonas, erroGuardar: falha.mensagem);
      return false;
    }
  }
}

/// `true` enquanto a nova foto de perfil está a ser enviada.
final fotoPerfilControladorProvider =
    NotifierProvider.autoDispose<FotoPerfilControlador, bool>(
      FotoPerfilControlador.new,
    );

/// Troca a foto de perfil: comprime (largura máxima de 1600 px), envia para
/// `publico/{perfilId}/perfil_{millis}.jpg` sem `upsert` e grava esse caminho
/// em `perfis.foto`.
class FotoPerfilControlador extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  /// Devolve a mensagem de erro, ou `null` se correu bem ou se desistiu.
  Future<String?> alterar(OrigemImagem origem) async {
    if (state) return null;
    final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
    if (id == null) return 'Entre na sua conta para alterar a foto.';

    final ImagemEscolhida? imagem;
    try {
      imagem = await ref.read(seletorImagemProvider).escolher(origem);
    } catch (_) {
      return 'Não foi possível abrir as fotografias. Autorize o acesso nas '
          'definições.';
    }
    if (imagem == null) return null;

    state = true;
    try {
      final Uint8List bytes;
      try {
        bytes = await ref
            .read(compressorImagemProvider)
            .comprimir(imagem.bytes);
      } catch (_) {
        throw const FalhaApp('Não foi possível preparar a fotografia.');
      }
      final repositorio = ref.read(prestadorRepositorioProvider);
      final caminho = await repositorio.carregarImagem(
        bucket: BucketsPrestador.publico,
        perfilId: id,
        tipo: 'perfil',
        bytes: bytes,
      );
      await repositorio.gravarFotoPerfil(perfilId: id, caminho: caminho);
      ref
        ..invalidate(perfilEditavelProvider)
        ..invalidate(painelProvider)
        ..invalidate(perfilPrestadorProvider(id));
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    } finally {
      state = false;
    }
  }
}
