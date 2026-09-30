import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../prestador/dados/repositorios/prestador_repositorio.dart';
import '../../dados/repositorios/autenticacao_repositorio.dart';

/// Sessão do Supabase, alimentada por `onAuthStateChange`.
final sessaoProvider = StreamProvider<Session?>(
  (ref) => ref.watch(autenticacaoRepositorioProvider).sessoes,
);

enum DestinoInicial { boasVindas, cliente, aguardoAprovacao, prestador }

/// Ecrã onde a app deve abrir, conforme a sessão e o registo de prestador.
///
/// Só volta a calcular quando muda o utilizador: a renovação do token a cada
/// hora emite uma sessão nova, mas não deve reconstruir a navegação.
final destinoInicialProvider = FutureProvider<DestinoInicial>((ref) async {
  try {
    final utilizadorId = await ref.watch(
      sessaoProvider.selectAsync((sessao) => sessao?.user.id),
    );
    if (utilizadorId == null) return DestinoInicial.boasVindas;

    final estado = await ref
        .watch(prestadorRepositorioProvider)
        .obterEstado(utilizadorId);
    return switch (estado) {
      null => DestinoInicial.cliente,
      'aprovado' => DestinoInicial.prestador,
      // `pendente` e qualquer outro estado (rejeitado, suspenso…): o painel de
      // prestador só abre depois de aprovado no painel do Supabase.
      _ => DestinoInicial.aguardoAprovacao,
    };
  } catch (erro, pilha) {
    Error.throwWithStackTrace(traduzirErro(erro), pilha);
  }
});

final sessaoControladorProvider = Provider<SessaoControlador>(
  (ref) => SessaoControlador(ref),
);

class SessaoControlador {
  SessaoControlador(this._ref);

  final Ref _ref;

  /// Termina a sessão. Devolve a mensagem de erro, ou `null` se correu bem.
  Future<String?> terminarSessao() async {
    try {
      await _ref.read(autenticacaoRepositorioProvider).terminarSessao();
      return null;
    } on FalhaApp catch (falha) {
      return falha.mensagem;
    }
  }

  /// Volta a ler a sessão e o estado do prestador (botão "tentar de novo" e
  /// "verificar de novo" no ecrã de aguardo).
  void recalcularDestino() {
    _ref.invalidate(sessaoProvider);
    _ref.invalidate(destinoInicialProvider);
  }
}
