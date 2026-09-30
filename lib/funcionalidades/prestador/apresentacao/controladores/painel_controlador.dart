import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/modelos/painel_prestador_modelo.dart';
import '../../dados/repositorios/prestador_repositorio.dart';

/// O prestador autenticado, para o painel. `null` se este utilizador não tem
/// registo de prestador (estado vazio). Volta a ler quando muda a sessão; "tentar de
/// novo" é `ref.invalidate(painelProvider)`.
final painelProvider = FutureProvider.autoDispose<PainelPrestadorModelo?>((
  ref,
) async {
  await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
  final perfilId = ref.read(autenticacaoRepositorioProvider).utilizadorId;
  if (perfilId == null) {
    throw const FalhaApp('Entre na sua conta para ver o seu painel.');
  }
  return ref.watch(prestadorRepositorioProvider).obterPainel(perfilId);
});

/// "Carlos Mabunda" → "Carlos", para a saudação.
String primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.first;
}

/// As três primeiras zonas e "+N" se houver mais.
String resumoZonas(List<String> zonas) {
  if (zonas.length <= 3) return zonas.join(', ');
  return '${zonas.take(3).join(', ')} +${zonas.length - 3}';
}

/// Indicadores do painel, pela ordem da grelha: (valor, rótulo). Só formata
/// o que vem da base; sem avaliações, mostra "—".
List<(String, String)> indicadoresDe(PainelPrestadorModelo painel) => [
  ('${painel.servicosFeitos}', 'Serviços realizados'),
  (
    painel.avaliacaoMedia == null
        ? '—'
        : '${painel.avaliacaoMedia!.toStringAsFixed(1)} ★',
    'Avaliação média',
  ),
  ('${painel.totalAvaliacoes}', 'Avaliações'),
  (
    painel.pctRecomenda == null ? '—' : '${painel.pctRecomenda!.round()}%',
    'Recomendam',
  ),
];
