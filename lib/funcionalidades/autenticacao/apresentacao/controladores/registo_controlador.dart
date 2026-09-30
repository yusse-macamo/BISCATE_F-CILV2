import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../dados/repositorios/autenticacao_repositorio.dart';
import 'validacoes.dart';

enum ResultadoRegisto { falhou, comSessao, confirmarEmail }

@immutable
class EstadoRegisto {
  const EstadoRegisto({
    this.municipio,
    this.zonaId,
    this.aEnviar = false,
    this.erros = const {},
    this.erroGeral,
  });

  final String? municipio;

  /// O `id` da zona ('fomento'), nunca o nome.
  final String? zonaId;
  final bool aEnviar;

  /// Erros por campo: `nome`, `telefone`, `email`, `palavraPasse`,
  /// `municipio`, `zona`.
  final Map<String, String> erros;
  final String? erroGeral;

  EstadoRegisto copiarCom({
    String? municipio,
    String? zonaId,
    bool limparZona = false,
    bool? aEnviar,
    Map<String, String>? erros,
    String? erroGeral,
  }) => EstadoRegisto(
    municipio: municipio ?? this.municipio,
    zonaId: limparZona ? null : (zonaId ?? this.zonaId),
    aEnviar: aEnviar ?? this.aEnviar,
    erros: erros ?? this.erros,
    erroGeral: erroGeral,
  );
}

final registoControladorProvider =
    NotifierProvider.autoDispose<RegistoControlador, EstadoRegisto>(
      RegistoControlador.new,
    );

class RegistoControlador extends AutoDisposeNotifier<EstadoRegisto> {
  static const comprimentoMinimoNome = 5;
  static const comprimentoMinimoPalavraPasse = 6;

  @override
  EstadoRegisto build() => const EstadoRegisto();

  void escolherMunicipio(String municipio) {
    if (municipio == state.municipio) return;
    state = state.copiarCom(
      municipio: municipio,
      limparZona: true,
      erros: {...state.erros}..remove('municipio'),
    );
  }

  void escolherZona(String zonaId) {
    state = state.copiarCom(
      zonaId: zonaId,
      erros: {...state.erros}..remove('zona'),
    );
  }

  void limparErro(String campo) {
    if (!state.erros.containsKey(campo)) return;
    state = state.copiarCom(erros: {...state.erros}..remove(campo));
  }

  Future<ResultadoRegisto> registar({
    required String nome,
    required String telefone,
    required String email,
    required String palavraPasse,
  }) async {
    if (state.aEnviar) return ResultadoRegisto.falhou;
    final nomeLimpo = nome.trim().replaceAll(RegExp(r'\s+'), ' ');
    final digitos = digitosTelefone(telefone);
    final emailLimpo = email.trim();

    // As mesmas regras do gatilho `trg_criar_perfil`: se o gatilho rejeitar,
    // o GoTrue não devolve a mensagem dele, por isso validamos antes.
    final erros = <String, String>{
      if (nomeLimpo.length < comprimentoMinimoNome)
        'nome': 'Indique o nome completo (pelo menos 5 letras).',
      if (!telefoneValido(digitos))
        'telefone': 'Indique um número móvel válido, ex.: 84 123 4567.',
      if (!emailValido(emailLimpo)) 'email': 'Indique um e-mail válido.',
      if (palavraPasse.length < comprimentoMinimoPalavraPasse)
        'palavraPasse': 'Use pelo menos 6 caracteres.',
      if (state.municipio == null) 'municipio': 'Escolha o município.',
      if (state.zonaId == null) 'zona': 'Escolha o bairro.',
    };
    if (erros.isNotEmpty) {
      state = state.copiarCom(erros: erros);
      return ResultadoRegisto.falhou;
    }

    state = state.copiarCom(aEnviar: true, erros: const {});
    try {
      final comSessao = await ref
          .read(autenticacaoRepositorioProvider)
          .registar(
            nome: nomeLimpo,
            telefone: digitos,
            email: emailLimpo,
            palavraPasse: palavraPasse,
            municipio: state.municipio!,
            zonaId: state.zonaId!,
          );
      state = state.copiarCom(aEnviar: false);
      return comSessao
          ? ResultadoRegisto.comSessao
          : ResultadoRegisto.confirmarEmail;
    } on FalhaApp catch (falha) {
      state = falha.campo == null
          ? state.copiarCom(aEnviar: false, erroGeral: falha.mensagem)
          : state.copiarCom(
              aEnviar: false,
              erros: {falha.campo!: falha.mensagem},
            );
      return ResultadoRegisto.falhou;
    }
  }
}
