import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'funcionalidades/autenticacao/apresentacao/ecras/ecra_encaminhamento.dart';
import 'nucleo/dados/cliente_supabase.dart';
import 'nucleo/tema/tema_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await iniciarSupabase();
  runApp(const ProviderScope(child: AppBiscateFacil()));
}

class AppBiscateFacil extends StatelessWidget {
  const AppBiscateFacil({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biscate Fácil',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: const EcraEncaminhamento(),
    );
  }
}
