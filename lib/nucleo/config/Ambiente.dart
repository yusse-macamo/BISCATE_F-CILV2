abstract final class Ambiente {
  static const String urlSupabase = String.fromEnvironment('SUPABASE_URL');
  static const String chaveAnonimaSupabase = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get configurado =>
      urlSupabase.isNotEmpty && chaveAnonimaSupabase.isNotEmpty;
}
