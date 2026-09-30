import 'package:supabase_flutter/supabase_flutter.dart';

/// Bucket de leitura pública (fotos de perfil, capa e portefólio).
const bucketPublico = 'publico';

/// URL público de uma foto a partir do caminho gravado na base
/// (`perfis.foto`). Pode já ser um URL completo.
///
/// Sem caminho, devolve `null`: o caminho nunca é reconstruído a partir do
/// perfil, porque o nome do ficheiro leva um carimbo temporal. Não faz
/// pedidos: só monta o URL, por isso o ecrã deve ter um substituto para
/// quando a imagem não carregar.
String? urlFotoPerfil(SupabaseClient cliente, String? caminho) {
  if (caminho == null || caminho.isEmpty) return null;
  if (caminho.startsWith('http')) return caminho;
  return cliente.storage.from(bucketPublico).getPublicUrl(caminho);
}
