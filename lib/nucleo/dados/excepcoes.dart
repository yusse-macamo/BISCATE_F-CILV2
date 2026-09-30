import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro já traduzido, pronto a mostrar ao utilizador.
///
/// [campo] diz a que campo do formulário pertence a mensagem, quando se sabe
/// (`nome`, `telefone`, `email`, `palavraPasse`); sem campo, é um erro geral.
class FalhaApp implements Exception {
  const FalhaApp(this.mensagem, {this.campo});

  final String mensagem;
  final String? campo;

  @override
  String toString() => mensagem;
}

const mensagemSemLigacao =
    'Sem ligação à internet. Verifique a rede e tente de novo.';
const mensagemInesperada = 'Algo correu mal. Tente de novo daqui a pouco.';

/// Corre [accao] e converte qualquer erro do Supabase ou da rede em [FalhaApp].
/// Os repositórios passam todas as chamadas por aqui.
///
/// Em modo de depuração, o erro original fica sempre registado na consola
/// antes de ser traduzido: a mensagem amigável esconde o que o servidor
/// respondeu, e é isso que é preciso para perceber uma falha.
Future<T> executarTraduzido<T>(Future<T> Function() accao) async {
  try {
    return await accao();
  } catch (erro, pilha) {
    registarErroOriginal(erro, pilha);
    Error.throwWithStackTrace(traduzirErro(erro), pilha);
  }
}

/// Escreve na consola, só em modo de depuração, o erro tal como veio do
/// Supabase ou da rede, com os campos que cada tipo traz e a pilha.
void registarErroOriginal(Object erro, StackTrace pilha) {
  if (!kDebugMode) return;
  final detalhe = switch (erro) {
    StorageException() =>
      'statusCode=${erro.statusCode} error=${erro.error} '
          'message=${erro.message}',
    PostgrestException() =>
      'code=${erro.code} message=${erro.message} '
          'details=${erro.details} hint=${erro.hint}',
    AuthException() =>
      'statusCode=${erro.statusCode} code=${erro.code} '
          'message=${erro.message}',
    _ => '$erro',
  };
  debugPrint('ERRO SUPABASE ${erro.runtimeType}: $detalhe');
  debugPrint('$pilha');
}

/// Mensagem a mostrar para um erro qualquer (já traduzido ou não).
String mensagemDe(Object erro) => traduzirErro(erro).mensagem;

FalhaApp traduzirErro(Object erro) {
  if (erro is FalhaApp) return erro;
  if (erro is AuthRetryableFetchException ||
      erro is TimeoutException ||
      _eErroDeRede(erro)) {
    return const FalhaApp(mensagemSemLigacao);
  }
  if (erro is AuthException) return _deAuth(erro);
  if (erro is PostgrestException) return _dePostgrest(erro);
  return const FalhaApp(mensagemInesperada);
}

// `SocketException` (dart:io) e `ClientException` (package:http) não são
// importáveis aqui sem partir a build web ou acrescentar dependências.
bool _eErroDeRede(Object erro) => const {
  'SocketException',
  'ClientException',
  'HandshakeException',
}.contains(erro.runtimeType.toString());

FalhaApp _deAuth(AuthException erro) {
  switch (erro.code) {
    case 'invalid_credentials':
      return const FalhaApp('E-mail ou palavra-passe errados.');
    case 'email_not_confirmed':
      return const FalhaApp(
        'Confirme o seu e-mail antes de entrar. Enviámos-lhe um link.',
      );
    case 'user_already_exists':
    case 'email_exists':
      return const FalhaApp(
        'Já existe uma conta com este e-mail.',
        campo: 'email',
      );
    case 'email_address_invalid':
      return const FalhaApp('Este e-mail não é válido.', campo: 'email');
    case 'weak_password':
      return const FalhaApp(
        'Palavra-passe fraca. Use pelo menos 6 caracteres, com letras e números.',
        campo: 'palavraPasse',
      );
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return const FalhaApp(
        'Demasiadas tentativas. Espere alguns minutos e tente de novo.',
      );
    case 'signup_disabled':
      return const FalhaApp('De momento não é possível criar contas novas.');
    case 'session_expired':
    case 'session_not_found':
    case 'refresh_token_not_found':
      return const FalhaApp('A sessão expirou. Entre de novo.');
  }
  // Quando um gatilho rejeita o registo, o GoTrue não passa a mensagem do
  // gatilho: devolve "Database error saving new user". Por isso o controlador
  // valida nome e telefone antes de enviar; isto é só a rede de segurança.
  final texto = erro.message.toLowerCase();
  if (texto.contains('database error')) {
    return const FalhaApp(
      'Não foi possível criar a conta. Confirme o nome e o telefone.',
    );
  }
  return const FalhaApp(mensagemInesperada);
}

FalhaApp _dePostgrest(PostgrestException erro) {
  switch (erro.code) {
    // `raise exception` nos gatilhos e funções: a mensagem já é nossa, em
    // português.
    case 'P0001':
      return FalhaApp(erro.message, campo: _campoNaMensagem(erro.message));
    case '23505':
      return const FalhaApp('Este registo já existe.');
    case '23514':
      return const FalhaApp(
        'Há um valor que não é aceite. Verifique os dados.',
      );
    case '42501':
      return const FalhaApp('Não tem permissão para fazer isto.');
    case 'PGRST301':
    case 'PGRST303':
      return const FalhaApp('A sessão expirou. Entre de novo.');
  }
  return const FalhaApp(mensagemInesperada);
}

String? _campoNaMensagem(String mensagem) {
  final texto = mensagem.toLowerCase();
  if (texto.contains('telefone')) return 'telefone';
  if (texto.contains('nome')) return 'nome';
  if (texto.contains('e-mail') || texto.contains('email')) return 'email';
  return null;
}
