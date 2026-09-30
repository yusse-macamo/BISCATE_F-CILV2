import 'package:flutter/foundation.dart';

import '../../../../nucleo/utilitarios/imagens.dart';

enum PassoCadastroPrestador { servico, zonas, documentos, envio }

enum TipoDocumento {
  fotoPerfil('perfil', 'Foto de perfil'),
  biFrente('bi_frente', 'BI, frente'),
  biVerso('bi_verso', 'BI, verso');

  const TipoDocumento(this.nomeFicheiro, this.rotulo);

  /// Nome no Storage: `{perfil_id}/{nomeFicheiro}.jpg`.
  final String nomeFicheiro;
  final String rotulo;
}

/// Etapas do envio, pela ordem em que correm. O ecrã mostra-as como lista de
/// progresso e, se uma falhar, repetir recomeça nessa etapa.
enum EtapaEnvio {
  preparar('A preparar as fotografias'),
  fotoPerfil('A enviar a foto de perfil'),
  fotoNoPerfil('A guardar a foto no seu perfil'),
  biFrente('A enviar a frente do BI'),
  biVerso('A enviar o verso do BI'),
  registo('A registar o cadastro'),
  documentos('A registar os documentos'),
  zonas('A guardar as zonas');

  const EtapaEnvio(this.rotulo);

  final String rotulo;
}

@immutable
class CadastroPrestadorEstado {
  const CadastroPrestadorEstado({
    this.passo = PassoCadastroPrestador.servico,
    this.categoriaId,
    this.bio = '',
    this.anos = '',
    this.zonas = const {},
    this.documentos = const {},
    this.caminhos = const {},
    this.erros = const {},
    this.aEnviar = false,
    this.etapaActual,
    this.etapasConcluidas = const {},
    this.erroEnvio,
    this.enviado = false,
  });

  final PassoCadastroPrestador passo;
  final String? categoriaId;

  /// Texto livre sobre o trabalho (opcional).
  final String bio;

  /// Anos de experiência, como o utilizador escreveu (opcional).
  final String anos;

  /// `id` das zonas escolhidas.
  final Set<String> zonas;
  final Map<TipoDocumento, ImagemEscolhida> documentos;

  /// Caminho no Storage de cada documento já enviado, como o repositório o
  /// devolveu. É isto que se grava na base.
  final Map<TipoDocumento, String> caminhos;

  /// Erros por campo: `categoria`, `anos`, `zonas`, `documentos`.
  final Map<String, String> erros;

  final bool aEnviar;
  final EtapaEnvio? etapaActual;
  final Set<EtapaEnvio> etapasConcluidas;
  final String? erroEnvio;
  final bool enviado;

  static const totalPassos = 3;

  /// 0, 1 ou 2 nos passos do formulário; o envio conta como o último.
  int get indicePasso => passo.index.clamp(0, totalPassos - 1);

  bool get temDocumentosObrigatorios =>
      documentos.containsKey(TipoDocumento.fotoPerfil) &&
      documentos.containsKey(TipoDocumento.biFrente);

  /// Etapas que este envio vai correr (o verso do BI é opcional).
  List<EtapaEnvio> get etapas => [
    for (final etapa in EtapaEnvio.values)
      if (etapa != EtapaEnvio.biVerso ||
          documentos.containsKey(TipoDocumento.biVerso))
        etapa,
  ];

  CadastroPrestadorEstado copiarCom({
    PassoCadastroPrestador? passo,
    String? categoriaId,
    String? bio,
    String? anos,
    Set<String>? zonas,
    Map<TipoDocumento, ImagemEscolhida>? documentos,
    Map<TipoDocumento, String>? caminhos,
    Map<String, String>? erros,
    bool? aEnviar,
    EtapaEnvio? etapaActual,
    bool limparEtapaActual = false,
    Set<EtapaEnvio>? etapasConcluidas,
    String? erroEnvio,
    bool limparErroEnvio = false,
    bool? enviado,
  }) => CadastroPrestadorEstado(
    passo: passo ?? this.passo,
    categoriaId: categoriaId ?? this.categoriaId,
    bio: bio ?? this.bio,
    anos: anos ?? this.anos,
    zonas: zonas ?? this.zonas,
    documentos: documentos ?? this.documentos,
    caminhos: caminhos ?? this.caminhos,
    erros: erros ?? this.erros,
    aEnviar: aEnviar ?? this.aEnviar,
    etapaActual: limparEtapaActual ? null : (etapaActual ?? this.etapaActual),
    etapasConcluidas: etapasConcluidas ?? this.etapasConcluidas,
    erroEnvio: limparErroEnvio ? null : (erroEnvio ?? this.erroEnvio),
    enviado: enviado ?? this.enviado,
  );
}
