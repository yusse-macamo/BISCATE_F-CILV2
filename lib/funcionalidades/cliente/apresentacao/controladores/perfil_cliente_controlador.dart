import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/perfil_cliente_repositorio.dart';

/// Perfil do utilizador autenticado. `null` sem sessão ou sem linha em
/// `perfis`. Volta a ler quando muda a sessão.
final perfilClienteProvider = FutureProvider<PerfilClienteModelo?>((ref) async {
  await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
  final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
  if (id == null) return null;
  return ref.watch(perfilClienteRepositorioProvider).obter(id);
});
