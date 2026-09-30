import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/ambiente.dart';

/// Inicializa o Supabase. Chamar uma vez em `main`, antes de `runApp`.
/// Recupera a sessão guardada, por isso o primeiro evento de
/// `onAuthStateChange` já traz o utilizador com sessão, se existir.
Future<void> iniciarSupabase() async {
  assert(Ambiente.configurado, 'Falta --dart-define-from-file=env.json');
  await Supabase.initialize(
    url: Ambiente.urlSupabase,
    anonKey: Ambiente.chaveAnonimaSupabase,
  );
}

/// Único ponto de acesso ao cliente. Os repositórios recebem-no daqui, para
/// poderem ser testados com `overrideWithValue`.
final clienteSupabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
