import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../nucleo/dados/cliente_supabase.dart';
import '../../../../nucleo/dados/excepcoes.dart';
import '../../../../nucleo/dados/leitura_json.dart';

final perfilClienteRepositorioProvider = Provider<PerfilClienteRepositorio>(
  (ref) => PerfilClienteRepositorio(ref.watch(clienteSupabaseProvider)),
);

/// O perfil do próprio utilizador, como o cabeçalho do início e a Conta o
/// mostram.
class PerfilClienteModelo {
  const PerfilClienteModelo({
    required this.nome,
    this.telefone,
    this.zona,
    this.municipio,
  });

  factory PerfilClienteModelo.fromJson(Map<String, dynamic> json) {
    final zona = lerObjecto(json['zonas']);
    return PerfilClienteModelo(
      nome: json['nome'] as String? ?? '',
      telefone: json['telefone'] as String?,
      zona: lerTexto(zona?['nome']),
      municipio: lerTexto(zona?['municipio']) ?? json['municipio'] as String?,
    );
  }

  final String nome;
  final String? telefone;
  final String? zona;
  final String? municipio;

  String get primeiroNome => nome.trim().split(RegExp(r'\s+')).first;

  /// "Polana Caniço A, Maputo", ou só a parte que houver.
  String get localizacao => [?zona, ?municipio].join(', ');

  String get inicial =>
      nome.trim().isEmpty ? '?' : nome.trim().characters.first.toUpperCase();
}

class PerfilClienteRepositorio {
  PerfilClienteRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<PerfilClienteModelo?> obter(String perfilId) =>
      executarTraduzido(() async {
        final linha = await _cliente
            .from('perfis')
            .select('nome, telefone, municipio, zonas(nome, municipio)')
            .eq('id', perfilId)
            .maybeSingle();
        return linha == null ? null : PerfilClienteModelo.fromJson(linha);
      });
}
