import 'package:flutter/material.dart';

import '../../nucleo/tema/tema_app.dart';

// Dados de exemplo retirados do design. Substituir por API quando houver backend.

class Avaliacao {
  const Avaliacao(this.quem, this.quando, this.texto);
  final String quem;
  final String quando;
  final String texto;
}

class Concurso {
  const Concurso({
    required this.area,
    required this.distancia,
    required this.restante,
    required this.titulo,
    required this.orcamento,
    required this.contagem,
    this.descricao = '',
    this.quando = 'Esta semana',
    this.cliente = 'Ana S. ★ 4.9',
  });
  final String area;
  final String distancia;
  final String restante;
  final String titulo;
  final String orcamento;
  final int contagem;
  final String descricao;
  final String quando;
  final String cliente;
}

enum TipoProposta {
  aceita('Aceita', CoresApp.verdeClaro, CoresApp.verdeEscuro),
  contraproposta('Contraproposta', CoresApp.ambarFundo, CoresApp.ambarFrente);

  const TipoProposta(this.rotulo, this.fundo, this.frente);
  final String rotulo;
  final Color fundo;
  final Color frente;
}

class Proposta {
  const Proposta(
    this.nome,
    this.avaliacao,
    this.servicos,
    this.preco,
    this.tipo,
    this.justificacao,
  );
  final String nome;
  final String avaliacao;
  final int servicos;
  final String preco;
  final TipoProposta tipo;
  final String justificacao;
}

class Plano {
  const Plano(this.nome, this.preco, this.periodo, this.descricao);
  final String nome;
  final String preco;
  final String periodo;
  final String descricao;
}

class ItemPortfolio {
  const ItemPortfolio(this.titulo, this.detalhe);
  final String titulo;
  final String detalhe;
}

class DadosExemplo {
  static const portfolio3 = ['quadro eléctrico', 'iluminação', 'tomadas'];

  static const avaliacoes = [
    Avaliacao(
      'Marta S.',
      'há 3 dias',
      '“Excelente profissional. Resolveu o problema do quadro no mesmo dia.”',
    ),
    Avaliacao(
      'João B.',
      'há 2 semanas',
      '“Muito pontual e o preço foi o combinado.”',
    ),
  ];

  static const portfolio = [
    ItemPortfolio('Quadro eléctrico', 'antes / depois'),
    ItemPortfolio('Iluminação LED', 'sala · Fomento'),
    ItemPortfolio('Tomadas cozinha', 'Machava'),
    ItemPortfolio('Loja comercial', 'vídeo 0:42'),
    ItemPortfolio('Portão eléctrico', 'Liberdade'),
  ];

  static const concursos = [
    Concurso(
      area: 'Polana Caniço A',
      distancia: '3 km',
      restante: '18 h',
      titulo: 'Substituir canos da casa de banho',
      orcamento: '1 500 MT',
      contagem: 3,
      descricao: 'Canos por baixo do lavatório com fuga. Trocar tubo e sifão.',
    ),
    Concurso(
      area: 'Maxaquene B',
      distancia: '5 km',
      restante: '2 dias',
      titulo: 'Instalar autoclismo novo',
      orcamento: '800 MT',
      contagem: 1,
    ),
    Concurso(
      area: 'Hulene',
      distancia: '8 km',
      restante: '6 h',
      titulo: 'Reparar fuga no tanque de água',
      orcamento: '1 200 MT',
      contagem: 5,
    ),
    Concurso(
      area: 'Malhangalene',
      distancia: '9 km',
      restante: '1 dia',
      titulo: 'Canalização completa de cozinha nova',
      orcamento: '6 000 MT',
      contagem: 2,
    ),
  ];

  static const propostas = [
    Proposta(
      'Hélio Cossa',
      '4.9',
      211,
      '1 500 MT',
      TipoProposta.aceita,
      '“Posso ir amanhã de manhã. Material incluído.”',
    ),
    Proposta(
      'Fernando Chissano',
      '4.7',
      93,
      '1 800 MT',
      TipoProposta.contraproposta,
      '“O orçamento não cobre o material: 2 sifões e tubo PVC novo custam cerca de 300 MT.”',
    ),
    Proposta(
      'Isac Langa',
      '4.6',
      57,
      '1 300 MT',
      TipoProposta.contraproposta,
      '“Faço por menos se puder ser na sexta-feira.”',
    ),
  ];

  static const planos = [
    Plano(
      'Teste gratuito',
      '0 MT',
      ' / 30 dias',
      'Perfil visível, até 5 pedidos por mês.',
    ),
    Plano(
      'Básico',
      '100 MT',
      ' / mês',
      'Pedidos ilimitados, portfólio até 10 fotos, selo verificado.',
    ),
    Plano(
      'Premium',
      '200 MT',
      ' / mês',
      'Tudo do Básico, destaque na pesquisa e na página inicial, estatísticas.',
    ),
  ];
}
