final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Móvel moçambicano: 8[2-7] seguido de 7 dígitos (a mesma regra do gatilho
/// `trg_criar_perfil`).
final _telefone = RegExp(r'^8[2-7]\d{7}$');

bool emailValido(String email) => _email.hasMatch(email);

/// Só os dígitos, sem o indicativo 258 se vier escrito.
String digitosTelefone(String telefone) {
  final digitos = telefone.replaceAll(RegExp(r'\D'), '');
  return digitos.length == 12 && digitos.startsWith('258')
      ? digitos.substring(3)
      : digitos;
}

bool telefoneValido(String digitos) => _telefone.hasMatch(digitos);
