import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/utilitarios/formatacao_mt.dart';
import '../../../autenticacao/apresentacao/controladores/sessao_controlador.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/assinatura_repositorio.dart';

/// Tudo o que o ecrã de assinatura mostra, lido de uma vez.
class SituacaoAssinatura {
  const SituacaoAssinatura({
    required this.planos,
    this.assinatura,
    this.gratuito,
  });

  final List<PlanoModelo> planos;
  final AssinaturaModelo? assinatura;
  final EstadoGratuitoModelo? gratuito;
}

final situacaoAssinaturaProvider =
    FutureProvider.autoDispose<SituacaoAssinatura>((ref) async {
      await ref.watch(sessaoProvider.selectAsync((sessao) => sessao?.user.id));
      final id = ref.read(autenticacaoRepositorioProvider).utilizadorId;
      if (id == null) {
        throw const FalhaApp('Entre na sua conta para ver a sua assinatura.');
      }
      final repositorio = ref.watch(assinaturaRepositorioProvider);
      final resultados = await Future.wait<Object?>([
        repositorio.planos(),
        repositorio.actual(id),
        repositorio.estadoGratuito(id),
      ]);
      return SituacaoAssinatura(
        planos: resultados[0] as List<PlanoModelo>,
        assinatura: resultados[1] as AssinaturaModelo?,
        gratuito: resultados[2] as EstadoGratuitoModelo?,
      );
    });

/// A frase por baixo do título: plano activo, período gratuito, ou nada.
String resumoSituacao(SituacaoAssinatura s) {
  final a = s.assinatura;
  if (a != null && a.activa) {
    final fim = a.fim;
    return fim == null
        ? 'Plano ${a.planoNome} activo.'
        : 'Plano ${a.planoNome} activo até ${fim.day}/${fim.month}/${fim.year}.';
  }
  final g = s.gratuito;
  if (g != null && (g.diasRestantes != null || g.trabalhosRestantes != null)) {
    final partes = [
      if (g.diasRestantes case final d?) d == 1 ? '1 dia' : '$d dias',
      if (g.trabalhosRestantes case final t?)
        t == 1 ? '1 trabalho' : '$t trabalhos',
    ];
    return 'Período gratuito: faltam ${partes.join(' ou ')}, o que acabar '
        'primeiro.';
  }
  return 'Escolha um plano para continuar a receber pedidos.';
}

String textoPrecoPlano(int preco) =>
    preco == 0 ? 'Grátis' : '${formatarMt(preco)} MT';
