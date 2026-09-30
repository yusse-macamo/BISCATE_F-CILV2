import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Imagem escolhida pelo utilizador, ainda sem compressão.
@immutable
class ImagemEscolhida {
  const ImagemEscolhida({required this.nome, required this.bytes});

  final String nome;
  final Uint8List bytes;
}

enum OrigemImagem { camara, galeria }

final seletorImagemProvider = Provider<SeletorImagem>((ref) => SeletorImagem());

/// Abre a câmara ou a galeria. Devolve `null` se o utilizador cancelar.
class SeletorImagem {
  final _picker = ImagePicker();

  Future<ImagemEscolhida?> escolher(OrigemImagem origem) async {
    final ficheiro = await _picker.pickImage(
      source: origem == OrigemImagem.camara
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (ficheiro == null) return null;
    return ImagemEscolhida(
      nome: ficheiro.name,
      bytes: await ficheiro.readAsBytes(),
    );
  }
}

final compressorImagemProvider = Provider<CompressorImagem>(
  (ref) => const CompressorImagem(),
);

/// Reduz fotografias antes do envio. A câmara devolve ficheiros de vários MB e
/// os dados móveis são caros.
class CompressorImagem {
  const CompressorImagem();

  static const larguraMaxima = 1600;
  static const qualidade = 80;

  /// JPEG com largura máxima de [larguraMaxima] px, sem EXIF (tira a
  /// localização) e já rodado conforme a orientação da câmara. Nunca amplia.
  Future<Uint8List> comprimir(Uint8List original) =>
      FlutterImageCompress.compressWithList(
        original,
        // O plugin reduz até a imagem caber em minWidth × minHeight pelo lado
        // que primeiro atingir o limite. Com minHeight = 1, o limite activo é
        // sempre a largura: fica com, no máximo, 1600 px de largura.
        minWidth: larguraMaxima,
        minHeight: 1,
        quality: qualidade,
        format: CompressFormat.jpeg,
      );
}
