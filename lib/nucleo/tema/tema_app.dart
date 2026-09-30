import 'package:flutter/material.dart';

/// Tokens extraídos do design "Biscate Facil Telas".
class CoresApp {
  static const pagina = Color(0xFFFAF9F6);
  static const tinta = Color(0xFF1C1B18);
  static const corpo = Color(0xFF3A3833);
  static const atenuado = Color(0xFF66625A);
  static const navInactivo = Color(0xFF8B877E);
  static const tracejado = Color(0xFFB9B4AA);
  static const borda = Color(0xFFE4E0D7);
  static const divisor = Color(0xFFF0EDE6);
  static const areia = Color(0xFFEEEBE4);
  static const areiaClara = Color(0xFFF4F2ED);

  static const verde = Color(0xFF1F7A4D);
  static const verdeEscuro = Color(0xFF16583A);
  static const verdeClaro = Color(0xFFE3F0E8);
  static const sobreVerdeAtenuado = Color(0xFFD4E8DB);
  static const sobreVerdeSuave = Color(0xFFDCEBE2);
  static const sobreVerdeEscuroAtenuado = Color(0xFFC9E0D2);

  static const estrela = Color(0xFFC98A1A);
  static const ambarFundo = Color(0xFFF6ECD6);
  static const ambarFrente = Color(0xFF7A5410);
  static const azulFundo = Color(0xFFE1EAF6);
  static const azulFrente = Color(0xFF1F4E86);
  static const vermelhoFundo = Color(0xFFF6E3DF);
  static const vermelhoFrente = Color(0xFF8E2F22);
  static const rejeitar = Color(0xFFA33A2A);

  static const riscaA = Color(0xFFE8E4DB);
  static const riscaB = Color(0xFFF1EEE7);
  static const avatarA = Color(0xFFCFCAC0);
  static const avatarB = Color(0xFFDCD8CE);
}

/// Atalho para estilos Manrope. `ls` é em em (como no CSS).
TextStyle estiloTexto(
  double tamanho, {
  FontWeight w = FontWeight.w400,
  Color? c,
  double? h,
  double ls = 0,
}) => TextStyle(
  fontSize: tamanho,
  fontWeight: w,
  color: c,
  height: h,
  letterSpacing: ls * tamanho,
);

TextStyle mono(double tamanho, {Color c = CoresApp.atenuado}) => TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: tamanho,
  color: c,
  fontWeight: FontWeight.w400,
);

const w500 = FontWeight.w500;
const w600 = FontWeight.w600;
const w700 = FontWeight.w700;
const w800 = FontWeight.w800;

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: ColorScheme.fromSeed(
      seedColor: CoresApp.verde,
      primary: CoresApp.verde,
      surface: CoresApp.pagina,
    ),
    scaffoldBackgroundColor: CoresApp.pagina,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CoresApp.tinta,
      displayColor: CoresApp.tinta,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: CoresApp.verde,
      selectionColor: CoresApp.verdeClaro,
      selectionHandleColor: CoresApp.verde,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CoresApp.tinta,
      contentTextStyle: estiloTexto(14, w: w600, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
