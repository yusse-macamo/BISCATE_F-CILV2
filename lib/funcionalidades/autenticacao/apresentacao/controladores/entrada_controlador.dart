import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../dados/repositorios/autenticacao_repositorio.dart';
import 'validacoes.dart';

@immutable
class EstadoEntrada {
  const EstadoEntrada({
    this.aEnviar = false,
    this.erros = const {},
    this.erroGeral,
  });

  final bool aEnviar;

  /// Erros por campo: `email`, `palavraPasse`.
  final Map<String, String> erros;
  final String? erroGeral;
}

final entradaControladorProvider =
    NotifierProvider.autoDispose<EntradaControlador, EstadoEntrada>(
      EntradaControlador.new,
    );

class EntradaControlador extends AutoDisposeNotifier<EstadoEntrada> {
  @override
  EstadoEntrada build() => const EstadoEntrada();

  /// Devolve `true` se entrou; a navegação fica a cargo do ecrã.
  Future<bool> entrar({
    required String email,
    required String palavraPasse,
  }) async {
    if (state.aEnviar) return false;
    final emailLimpo = email.trim();
    final erros = <String, String>{
      if (!emailValido(emailLimpo)) 'email': 'Indique um e-mail válido.',
      if (palavraPasse.isEmpty) 'palavraPasse': 'Indique a palavra-passe.',
    };
    if (erros.isNotEmpty) {
      state = EstadoEntrada(erros: erros);
      return false;
    }

    state = const EstadoEntrada(aEnviar: true);
    try {
      await ref
          .read(autenticacaoRepositorioProvider)
          .entrar(email: emailLimpo, palavraPasse: palavraPasse);
      state = const EstadoEntrada();
      return true;
    } on FalhaApp catch (falha) {
      state = falha.campo == null
          ? EstadoEntrada(erroGeral: falha.mensagem)
          : EstadoEntrada(erros: {falha.campo!: falha.mensagem});
      return false;
    }
  }

  void limparErro(String campo) {
    if (!state.erros.containsKey(campo) && state.erroGeral == null) return;
    state = EstadoEntrada(
      aEnviar: state.aEnviar,
      erros: {...state.erros}..remove(campo),
    );
  }
}
