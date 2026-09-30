/// "1500" -> "1 500" (separador de milhares com espaço, como no design).
String formatarMt(int valor) {
  final s = valor.abs().toString();
  final b = StringBuffer(valor < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

int lerMt(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
