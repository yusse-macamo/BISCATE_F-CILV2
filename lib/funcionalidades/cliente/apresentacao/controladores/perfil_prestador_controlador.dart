import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../nucleo/dados/excepcoes.dart';
import '../../../autenticacao/dados/repositorios/autenticacao_repositorio.dart';
import '../../../prestador/dados/repositorios/portfolio_repositorio.dart';
import '../../dados/modelos/prestador_publico_modelo.dart';
import '../../dados/repositorios/avaliacoes_repositorio.dart';
import '../../dados/repositorios/favoritos_repositorio.dart';
import '../../dados/repositorios/procura_repositorio.dart';

/// Um prestador, para o ecrã de perfil. `null` se não existir ou não estiver
/// visível (estado vazio). A visibilidade é da RLS.
final perfilPrestadorProvider = FutureProvider.autoDispose
    .family<PrestadorPublicoModelo?, String>((ref, prestadorId) async {
      if (prestadorId.isEmpty) return null;
      return ref.watch(procuraRepositorioProvider).obter(prestadorId);
    });

/// Se o cliente marcou este prestador como favorito.
final favoritoProvider = AsyncNotifierProvider.autoDispose
    .family<FavoritoControlador, bool, String>(FavoritoControlador.new);

class FavoritoControlador extends AutoDisposeFamilyAsyncNotifier<bool, String> {
  String? get _clienteId =>
      ref.read(autenticacaoRepositorioProvider).utilizadorId;

  @override
  Future<bool> build(String prestadorId) async {
    final clienteId = _clienteId;
    if (clienteId == null || prestadorId.isEmpty) return false;
    return ref
        .watch(favoritosRepositorioProvider)
        .eFavorito(clienteId, prestadorId);
  }

  /// Marca ou desmarca. O coração muda logo; se a base recusar, volta atrás
  /// e devolve a mensagem para o ecrã mostrar. `null` se correu bem.
  Future<String?> alternar() async {
    final clienteId = _clienteId;
    if (clienteId == null) return 'Entre na sua conta para guardar favoritos.';
    final antes = state.valueOrNull ?? false;
    state = AsyncData(!antes);
    final repositorio = ref.read(favoritosRepositorioProvider);
    try {
      if (antes) {
        await repositorio.remover(clienteId, arg);
      } else {
        await repositorio.adicionar(clienteId, arg);
      }
      return null;
    } on FalhaApp catch (falha) {
      state = AsyncData(antes);
      return falha.mensagem;
    }
  }
}

/// Trabalhos publicados pelo prestador (`portfolio`).
final portfolioPrestadorProvider = FutureProvider.autoDispose
    .family<List<ItemPortfolioModelo>, String>(
      (ref, prestadorId) =>
          ref.watch(portfolioRepositorioProvider).listar(prestadorId),
    );

/// As avaliações mais recentes do prestador (`avaliacoes`).
final avaliacoesPrestadorProvider = FutureProvider.autoDispose
    .family<List<AvaliacaoModelo>, String>(
      (ref, prestadorId) =>
          ref.watch(avaliacoesRepositorioProvider).recentes(prestadorId),
    );

/// "Marta Sitoe" → "Marta S."; sem nome legível, "Cliente".
String autorAbreviado(String? nome) {
  final partes = (nome ?? '').trim().split(RegExp(r'\s+'));
  if (partes.first.isEmpty) return 'Cliente';
  if (partes.length == 1) return partes.first;
  return '${partes.first} ${partes.last[0].toUpperCase()}.';
}

/// "hoje", "há 3 dias", "há 2 semanas", "há 4 meses".
String haQuantoTempo(DateTime? data, DateTime agora) {
  if (data == null) return '';
  final dias = agora.difference(data).inDays;
  if (dias < 1) return 'hoje';
  if (dias < 7) return dias == 1 ? 'há 1 dia' : 'há $dias dias';
  if (dias < 30) {
    final s = dias ~/ 7;
    return s == 1 ? 'há 1 semana' : 'há $s semanas';
  }
  final m = dias ~/ 30;
  return m == 1 ? 'há 1 mês' : 'há $m meses';
}
