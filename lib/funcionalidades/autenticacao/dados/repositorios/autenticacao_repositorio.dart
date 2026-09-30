import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';

final autenticacaoRepositorioProvider = Provider<AutenticacaoRepositorio>(
  (ref) => AutenticacaoRepositorio(ref.watch(clienteSupabaseProvider)),
);

class AutenticacaoRepositorio {
  AutenticacaoRepositorio(this._cliente);

  final SupabaseClient _cliente;

  /// Sessão actual e cada mudança seguinte. O stream do GoTrue repete os
  /// eventos anteriores a quem subscreve, por isso o primeiro valor é o estado
  /// com que a app arrancou.
  Stream<Session?> get sessoes =>
      _cliente.auth.onAuthStateChange.map((evento) => evento.session);

  /// `auth.uid()` do utilizador com sessão, ou `null` se não houver sessão.
  String? get utilizadorId => _cliente.auth.currentUser?.id;

  Future<void> entrar({required String email, required String palavraPasse}) =>
      executarTraduzido(
        () => _cliente.auth.signInWithPassword(
          email: email,
          password: palavraPasse,
        ),
      );

  /// Cria a conta. O perfil em `perfis` é criado pelo gatilho
  /// `trg_criar_perfil` na mesma transacção; a app não insere em `perfis`.
  ///
  /// Devolve `true` se a conta ficou já com sessão, e `false` se o projecto
  /// exige confirmação do e-mail antes de entrar.
  Future<bool> registar({
    required String nome,
    required String telefone,
    required String email,
    required String palavraPasse,
    required String municipio,
    required String zonaId,
  }) => executarTraduzido(() async {
    final resposta = await _cliente.auth.signUp(
      email: email,
      password: palavraPasse,
      data: {
        'nome': nome,
        'telefone': telefone,
        'municipio': municipio,
        'zona_id': zonaId,
      },
    );
    return resposta.session != null;
  });

  Future<void> terminarSessao() =>
      executarTraduzido(() => _cliente.auth.signOut());
}
