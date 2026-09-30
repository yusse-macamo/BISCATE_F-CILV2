import 'package:biscate_facil/funcionalidades/prestador/apresentacao/controladores/painel_controlador.dart';
import 'package:biscate_facil/funcionalidades/prestador/dados/modelos/painel_prestador_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Forma da resposta de `prestadores` com `perfis`, `categorias` e
/// `prestador_zonas(zonas(nome))` embebidos.
const _linha = {
  'perfil_id': 'p-1',
  'titulo': null,
  'verificado': true,
  'avaliacao_media': 4.75,
  'total_avaliacoes': 62,
  'servicos_feitos': 148,
  'pct_recomenda': 96,
  'perfis': {'nome': 'Carlos Mabunda', 'foto': null},
  'categorias': {'nome': 'Electricidade'},
  'prestador_zonas': [
    {
      'zonas': {'nome': 'Fomento'},
    },
    {
      'zonas': {'nome': 'Machava'},
    },
    {
      'zonas': {'nome': 'Liberdade'},
    },
    {
      'zonas': {'nome': 'Tsalala'},
    },
  ],
};

void main() {
  test('lê o prestador com perfil, categoria e zonas', () {
    final painel = PainelPrestadorModelo.fromJson(_linha, fotoUrl: null);
    expect(painel.nome, 'Carlos Mabunda');
    expect(primeiroNome(painel.nome), 'Carlos');
    expect(painel.descricao, 'Electricidade', reason: 'sem título');
    expect(resumoZonas(painel.zonas), 'Fomento, Machava, Liberdade +1');
    expect(painel.verificado, isTrue);
  });

  test('o título, quando existe, substitui a categoria', () {
    final painel = PainelPrestadorModelo.fromJson({
      ..._linha,
      'titulo': 'Electricista certificado',
    }, fotoUrl: null);
    expect(painel.descricao, 'Electricista certificado');
  });

  test('indicadores mostram os valores da base, sem recalcular', () {
    final painel = PainelPrestadorModelo.fromJson(_linha, fotoUrl: null);
    expect(indicadoresDe(painel), [
      ('148', 'Serviços realizados'),
      ('4.8 ★', 'Avaliação média'),
      ('62', 'Avaliações'),
      ('96%', 'Recomendam'),
    ]);
  });

  test('sem avaliações, média e recomendação mostram "—"', () {
    final painel = PainelPrestadorModelo.fromJson({
      ..._linha,
      'avaliacao_media': null,
      'total_avaliacoes': 0,
      'pct_recomenda': null,
      'prestador_zonas': <Object>[],
    }, fotoUrl: null);
    expect(indicadoresDe(painel)[1].$1, '—');
    expect(indicadoresDe(painel)[3].$1, '—');
    expect(painel.zonas, isEmpty);
  });
}
