import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/dados/excepcoes.dart';
import '../../nucleo/tema/tema_app.dart';

void mostrarAviso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem)));
}

/// Ecrã base: fundo, cor dos ícones da barra de estado e safe area.
class EcraBase extends StatelessWidget {
  const EcraBase({
    super.key,
    required this.child,
    this.fundo = CoresApp.pagina,
    this.barraEstadoClara = false,
    this.topoSeguro = true,
    this.barraInferior,
  });

  final Widget child;
  final Color fundo;
  final bool barraEstadoClara;
  final bool topoSeguro;
  final Widget? barraInferior;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barraEstadoClara
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      child: Scaffold(
        backgroundColor: fundo,
        body: SafeArea(
          top: topoSeguro,
          bottom: barraInferior == null,
          child: child,
        ),
        bottomNavigationBar: barraInferior,
      ),
    );
  }
}

/// Scroll que preenche a altura disponível, permitindo `Spacer()` para
/// empurrar o botão principal para o fundo (como o `flex:1` do design).
class ScrollPreenchido extends StatelessWidget {
  const ScrollPreenchido({
    super.key,
    required this.preenchimento,
    required this.children,
    this.espaco = 14,
  });

  final EdgeInsets preenchimento;
  final List<Widget> children;
  final double espaco;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: preenchimento,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: comEspaco(children, espaco),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intercala espaçamento entre filhos (equivalente a `gap` no flex CSS).
/// `Spacer` não recebe espaço extra à sua volta a mais do que um gap.
List<Widget> comEspaco(
  List<Widget> itens,
  double espaco, {
  Axis eixo = Axis.vertical,
}) {
  final saida = <Widget>[];
  for (var i = 0; i < itens.length; i++) {
    if (i > 0) {
      saida.add(
        eixo == Axis.vertical
            ? SizedBox(height: espaco)
            : SizedBox(width: espaco),
      );
    }
    saida.add(itens[i]);
  }
  return saida;
}

class Toque extends StatelessWidget {
  const Toque({super.key, required this.child, this.aoTocar, this.raio = 12});

  final Widget child;
  final VoidCallback? aoTocar;
  final double raio;

  @override
  Widget build(BuildContext context) {
    if (aoTocar == null) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(raio),
        child: child,
      ),
    );
  }
}

class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({
    super.key,
    this.aoTocar,
    this.tamanho = 44,
    this.preenchido = false,
  });

  final VoidCallback? aoTocar;
  final double tamanho;
  final bool preenchido;

  @override
  Widget build(BuildContext context) {
    return Toque(
      raio: 12,
      aoTocar: aoTocar ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: preenchido ? Colors.white : null,
          borderRadius: BorderRadius.circular(12),
          border: preenchido ? null : Border.all(color: CoresApp.borda),
        ),
        child: Text('←', style: estiloTexto(preenchido ? 14 : 18)),
      ),
    );
  }
}

/// Linha "← Título / subtítulo" usada no topo de vários ecrãs.
class LinhaTitulo extends StatelessWidget {
  const LinhaTitulo({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.tamanhoTitulo = 18,
  });

  final String titulo;
  final String? subtitulo;
  final double tamanhoTitulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BotaoVoltar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: estiloTexto(tamanhoTitulo, w: w800)),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  style: estiloTexto(12.5, c: CoresApp.atenuado),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RotuloCampo extends StatelessWidget {
  const RotuloCampo(this.texto, {super.key, this.dica});

  final String texto;
  final String? dica;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: texto,
            style: estiloTexto(13, w: w700),
          ),
          if (dica != null)
            TextSpan(
              text: ' $dica',
              style: estiloTexto(13, w: w500, c: CoresApp.atenuado),
            ),
        ],
      ),
    );
  }
}

class ComRotulo extends StatelessWidget {
  const ComRotulo({
    super.key,
    required this.rotulo,
    required this.child,
    this.dica,
    this.espaco = 6,
    this.ajuda,
    this.erro,
  });

  final String rotulo;
  final String? dica;
  final Widget child;
  final double espaco;
  final String? ajuda;

  /// Mensagem de validação do campo; quando existe, aparece por baixo dele.
  final String? erro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comEspaco([
        RotuloCampo(rotulo, dica: dica),
        child,
        if (ajuda != null)
          Text(ajuda!, style: estiloTexto(12, c: CoresApp.atenuado)),
        if (erro != null) MensagemErro(erro!),
      ], espaco),
    );
  }
}

/// Campo de texto com o visual do design: caixa branca, borda 1px
/// #E4E0D7 que passa a 1.5px verde com foco (ou quando `emphasized`).
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    this.valorInicial = '',
    this.altura = 48,
    this.multilinha = false,
    this.tamanhoFonte = 15,
    this.raio = 12,
    this.prefixo,
    this.sufixo,
    this.estilo,
    this.ocultar = false,
    this.destacado = false,
    this.tipoTeclado,
    this.aoMudar,
    this.textoDica,
    this.controlador,
    this.alinhamentoTexto = TextAlign.start,
    this.alturaMinima = false,
    this.margemH = 14,
  });

  final String valorInicial;
  final double altura;
  final bool multilinha;
  final double tamanhoFonte;
  final double raio;
  final Widget? prefixo;
  final Widget? sufixo;
  final TextStyle? estilo;
  final bool ocultar;
  final bool destacado;
  final TextInputType? tipoTeclado;
  final ValueChanged<String>? aoMudar;
  final String? textoDica;
  final TextEditingController? controlador;
  final TextAlign alinhamentoTexto;

  /// Se true, `height` é apenas altura mínima e a caixa cresce com o texto.
  final bool alturaMinima;
  final double margemH;

  @override
  State<CampoTexto> createState() => _EstadoCampoTexto();
}

class _EstadoCampoTexto extends State<CampoTexto> {
  late final TextEditingController _controlador =
      widget.controlador ?? TextEditingController(text: widget.valorInicial);
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controlador == null) _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = _foco.hasFocus || widget.destacado;
    final estilo =
        widget.estilo ??
        estiloTexto(widget.tamanhoFonte, h: widget.multilinha ? 1.45 : null);
    final campo = TextField(
      controller: _controlador,
      focusNode: _foco,
      obscureText: widget.ocultar,
      obscuringCharacter: '•',
      keyboardType: widget.multilinha
          ? TextInputType.multiline
          : widget.tipoTeclado,
      maxLines: widget.multilinha ? null : 1,
      expands: widget.multilinha && !widget.alturaMinima,
      textAlign: widget.alinhamentoTexto,
      textAlignVertical: widget.multilinha
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      style: estilo.copyWith(color: CoresApp.tinta),
      onChanged: widget.aoMudar,
      decoration: InputDecoration.collapsed(
        hintText: widget.textoDica,
        hintStyle: estilo.copyWith(color: CoresApp.atenuado),
      ),
    );
    return GestureDetector(
      onTap: () => _foco.requestFocus(),
      child: Container(
        height: widget.alturaMinima ? null : widget.altura,
        constraints: widget.alturaMinima
            ? BoxConstraints(minHeight: widget.altura)
            : null,
        padding: widget.multilinha
            ? EdgeInsets.symmetric(horizontal: widget.margemH, vertical: 10)
            : EdgeInsets.symmetric(
                horizontal: widget.margemH,
                vertical: widget.alturaMinima ? 10 : 0,
              ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.raio),
          border: Border.all(
            color: activo ? CoresApp.verde : CoresApp.borda,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: widget.multilinha
            ? campo
            : Row(
                children: [
                  if (widget.prefixo != null) ...[
                    widget.prefixo!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: campo),
                  if (widget.sufixo != null) ...[
                    const SizedBox(width: 8),
                    widget.sufixo!,
                  ],
                ],
              ),
      ),
    );
  }
}

/// Caixa de selecção ("valor ▾") que abre uma folha de opções.
class CaixaSeleccao extends StatelessWidget {
  const CaixaSeleccao({
    super.key,
    required this.valor,
    required this.opcoes,
    required this.aoMudar,
    this.altura = 48,
    this.tamanhoFonte = 15,
    this.titulo,
    this.mostrarSeta = true,
    this.activa = true,
  });

  final String valor;
  final List<String> opcoes;
  final ValueChanged<String> aoMudar;
  final double altura;
  final double tamanhoFonte;
  final String? titulo;
  final bool mostrarSeta;

  /// Se false, não abre as opções e o texto aparece atenuado.
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return Toque(
      aoTocar: activa
          ? () async {
              final v = await escolherOpcao(
                context,
                opcoes,
                valor,
                titulo: titulo,
              );
              if (v != null) aoMudar(v);
            }
          : null,
      child: Container(
        height: altura,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CoresApp.borda),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valor,
                style: estiloTexto(
                  tamanhoFonte,
                  c: activa ? null : CoresApp.atenuado,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (mostrarSeta)
              Text('▾', style: estiloTexto(tamanhoFonte, c: CoresApp.atenuado)),
          ],
        ),
      ),
    );
  }
}

Future<String?> escolherOpcao(
  BuildContext context,
  List<String> opcoes,
  String actual, {
  String? titulo,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: CoresApp.pagina,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CoresApp.borda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (titulo != null) ...[
              const SizedBox(height: 14),
              Text(titulo, style: estiloTexto(17, w: w800)),
            ],
            const SizedBox(height: 8),
            for (final o in opcoes)
              Toque(
                aoTocar: () => Navigator.pop(ctx, o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o,
                          style: estiloTexto(15, w: o == actual ? w700 : w500),
                        ),
                      ),
                      if (o == actual)
                        Text(
                          '✓',
                          style: estiloTexto(15, w: w800, c: CoresApp.verde),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario(
    this.rotulo, {
    super.key,
    required this.aoTocar,
    this.altura = 54,
    this.raio = 14,
    this.tamanhoFonte = 16,
    this.fundo = CoresApp.verde,
    this.frente = Colors.white,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final double altura;
  final double raio;
  final double tamanhoFonte;
  final Color fundo;
  final Color frente;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(raio),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(raio),
        child: SizedBox(
          height: altura,
          child: Center(
            child: Text(
              rotulo,
              style: estiloTexto(tamanhoFonte, w: w700, c: frente),
            ),
          ),
        ),
      ),
    );
  }
}

class BotaoContorno extends StatelessWidget {
  const BotaoContorno(
    this.rotulo, {
    super.key,
    required this.aoTocar,
    this.altura = 54,
    this.raio = 14,
    this.tamanhoFonte = 16,
    this.cor = CoresApp.tinta,
    this.corBorda = CoresApp.borda,
    this.larguraBorda = 1,
    this.largura,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final double altura;
  final double raio;
  final double tamanhoFonte;
  final Color cor;
  final Color corBorda;
  final double larguraBorda;
  final double? largura;

  @override
  Widget build(BuildContext context) {
    return Toque(
      aoTocar: aoTocar,
      raio: raio,
      child: Container(
        height: altura,
        width: largura,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(raio),
          border: Border.all(color: corBorda, width: larguraBorda),
        ),
        child: Text(
          rotulo,
          style: estiloTexto(tamanhoFonte, w: w700, c: cor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Chip arredondado (filtros). `selected` usa verde, ou `selectedColor`.
class Pilula extends StatelessWidget {
  const Pilula(
    this.rotulo, {
    super.key,
    this.seleccionado = false,
    this.aoTocar,
    this.corSeleccionada = CoresApp.verde,
    this.margemH = 12,
  });

  final String rotulo;
  final bool seleccionado;
  final VoidCallback? aoTocar;
  final Color corSeleccionada;
  final double margemH;

  @override
  Widget build(BuildContext context) {
    return Toque(
      raio: 17,
      aoTocar: aoTocar,
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: margemH),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado ? corSeleccionada : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: seleccionado ? corSeleccionada : CoresApp.borda,
          ),
        ),
        child: Text(
          rotulo,
          style: estiloTexto(
            13,
            w: w700,
            c: seleccionado ? Colors.white : CoresApp.tinta,
          ),
        ),
      ),
    );
  }
}

/// Controlo segmentado (Telefone/Email, Activos/Histórico…).
class Segmentado extends StatelessWidget {
  const Segmentado({
    super.key,
    required this.rotulos,
    required this.indice,
    required this.aoMudar,
    this.altura = 40,
  });

  final List<String> rotulos;
  final int indice;
  final ValueChanged<int> aoMudar;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CoresApp.areia,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: comEspaco(
          [
            for (var i = 0; i < rotulos.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aoMudar(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: altura,
                    alignment: Alignment.center,
                    decoration: i == indice
                        ? BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      rotulos[i],
                      style: estiloTexto(
                        14,
                        w: i == indice ? w700 : w600,
                        c: i == indice ? CoresApp.tinta : CoresApp.atenuado,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          4,
          eixo: Axis.horizontal,
        ),
      ),
    );
  }
}

class Selo extends StatelessWidget {
  const Selo(
    this.texto, {
    super.key,
    required this.fundo,
    required this.frente,
    this.tamanhoFonte = 12,
    this.preenchimento = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    this.raio = 10,
  });

  final String texto;
  final Color fundo;
  final Color frente;
  final double tamanhoFonte;
  final EdgeInsets preenchimento;
  final double raio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: preenchimento,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(raio),
      ),
      child: Text(
        texto,
        style: estiloTexto(tamanhoFonte, w: w800, c: frente),
      ),
    );
  }
}

/// Etiqueta cinza-areia (ex.: "Polana Caniço A").
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.margemH = 9});

  final String texto;
  final double margemH;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: margemH, vertical: 5),
      decoration: BoxDecoration(
        color: CoresApp.areia,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(texto, style: estiloTexto(12, w: w700)),
    );
  }
}

class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.child,
    this.preenchimento = const EdgeInsets.all(14),
    this.raio = 16,
    this.corBorda = CoresApp.borda,
    this.larguraBorda = 1,
    this.cor = Colors.white,
    this.aoTocar,
  });

  final Widget child;
  final EdgeInsets preenchimento;
  final double raio;
  final Color corBorda;
  final double larguraBorda;
  final Color cor;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(raio),
        side: BorderSide(color: corBorda, width: larguraBorda),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(padding: preenchimento, child: child),
      ),
    );
  }
}

/// Placeholder de imagem com riscas diagonais (repeating-linear-gradient 135deg).
class Riscado extends StatelessWidget {
  const Riscado({
    super.key,
    this.largura,
    this.altura,
    this.raio = 12,
    this.a = CoresApp.riscaA,
    this.b = CoresApp.riscaB,
    this.banda = 5,
    this.child,
    this.borda,
  });

  final double? largura;
  final double? altura;
  final double raio;
  final Color a;
  final Color b;
  final double banda;
  final Widget? child;
  final BoxBorder? borda;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largura,
      height: altura,
      foregroundDecoration: borda == null
          ? null
          : BoxDecoration(
              border: borda,
              borderRadius: BorderRadius.circular(raio),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(raio),
        child: CustomPaint(
          painter: _PintorRiscas(a, b, banda),
          child: child == null ? const SizedBox.expand() : child!,
        ),
      ),
    );
  }
}

class _PintorRiscas extends CustomPainter {
  _PintorRiscas(this.a, this.b, this.banda);

  final Color a;
  final Color b;
  final double banda;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final pincel = Paint()..color = a;
    // Bandas perpendiculares a (1,1): x + y = c, largura `band` ao longo da diagonal.
    final passo = banda * math.sqrt2;
    final total = size.width + size.height;
    for (double c = 0; c < total; c += passo * 2) {
      final caminho = Path()
        ..moveTo(c, 0)
        ..lineTo(c + passo, 0)
        ..lineTo(c + passo - total, total)
        ..lineTo(c - total, total)
        ..close();
      canvas.drawPath(caminho, pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorRiscas old) =>
      old.a != a || old.b != b || old.banda != banda;
}

/// Caixa com borda tracejada (botões "+ Adicionar").
class CaixaTracejada extends StatelessWidget {
  const CaixaTracejada({
    super.key,
    required this.child,
    this.raio = 12,
    this.largura,
    this.altura,
    this.aoTocar,
  });

  final Widget child;
  final double raio;
  final double? largura;
  final double? altura;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Toque(
      raio: raio,
      aoTocar: aoTocar,
      child: CustomPaint(
        painter: _PintorTracejado(raio),
        child: SizedBox(
          width: largura,
          height: altura,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PintorTracejado extends CustomPainter {
  _PintorTracejado(this.raio);

  final double raio;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      Radius.circular(raio),
    );
    final pincel = Paint()
      ..color = CoresApp.tracejado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorTracejado old) => old.raio != raio;
}

class PontoVerificado extends StatelessWidget {
  const PontoVerificado({super.key, this.tamanho = 16});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: CoresApp.verde,
        shape: BoxShape.circle,
      ),
      child: Text(
        '✓',
        style: estiloTexto(tamanho * 0.62, w: w800, c: Colors.white, h: 1),
      ),
    );
  }
}

/// "★ 4.8" com estrela dourada.
TextSpan spanEstrela(
  String avaliacao, {
  double tamanho = 13,
  FontWeight w = w700,
}) => TextSpan(
  children: [
    TextSpan(
      text: '★',
      style: estiloTexto(tamanho, c: CoresApp.estrela, w: w),
    ),
    TextSpan(
      text: ' $avaliacao',
      style: estiloTexto(tamanho, w: w),
    ),
  ],
);

class ItemNavegacao {
  const ItemNavegacao(this.rotulo, {this.circulo = false});
  final String rotulo;
  final bool circulo;
}

class NavegacaoInferior extends StatelessWidget {
  const NavegacaoInferior({
    super.key,
    required this.itens,
    required this.indice,
    required this.aoTocar,
  });

  final List<ItemNavegacao> itens;
  final int indice;
  final ValueChanged<int> aoTocar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CoresApp.borda)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              for (var i = 0; i < itens.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => aoTocar(i),
                    child: _CelulaNavegacao(
                      item: itens[i],
                      activo: i == indice,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelulaNavegacao extends StatelessWidget {
  const _CelulaNavegacao({required this.item, required this.activo});

  final ItemNavegacao item;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final cor = activo ? CoresApp.verde : CoresApp.navInactivo;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: activo ? cor : null,
            shape: item.circulo ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: item.circulo ? null : BorderRadius.circular(6),
            border: activo ? null : Border.all(color: cor, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.rotulo,
          style: estiloTexto(11.5, w: w700, c: cor),
        ),
      ],
    );
  }
}

/// Linha "rótulo ........ valor" dentro de cartões de resumo.
class LinhaChaveValor extends StatelessWidget {
  const LinhaChaveValor({
    super.key,
    required this.rotulo,
    required this.valor,
    this.ultimo = false,
  });

  final String rotulo;
  final Widget valor;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(bottom: BorderSide(color: CoresApp.divisor)),
      ),
      child: Row(
        children: [
          Text(rotulo, style: estiloTexto(14, c: CoresApp.atenuado)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: valor),
          ),
        ],
      ),
    );
  }
}

/// Grelha simples com N colunas de largura igual (CSS grid repeat(N,1fr)).
class GrelhaUniforme extends StatelessWidget {
  const GrelhaUniforme({
    super.key,
    required this.colunas,
    required this.children,
    this.espacoH = 10,
    this.espacoV = 10,
    this.flex,
  });

  final int colunas;
  final List<Widget> children;
  final double espacoH;
  final double espacoV;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    for (var i = 0; i < children.length; i += colunas) {
      final celulas = <Widget>[];
      for (var j = 0; j < colunas; j++) {
        final k = i + j;
        celulas.add(
          Expanded(
            flex: flex?[j] ?? 1,
            child: k < children.length ? children[k] : const SizedBox(),
          ),
        );
      }
      linhas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: comEspaco(celulas, espacoH, eixo: Axis.horizontal),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comEspaco(linhas, espacoV),
    );
  }
}

/// Texto de erro de um campo ou de um formulário.
class MensagemErro extends StatelessWidget {
  const MensagemErro(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: estiloTexto(12.5, w: w600, c: CoresApp.vermelhoFrente, h: 1.35),
    );
  }
}

/// Indicador de carregamento centrado, para ecrãs e secções que esperam dados.
class EstadoCarregar extends StatelessWidget {
  const EstadoCarregar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: CoresApp.verde),
      ),
    );
  }
}

/// Erro ao carregar dados, com botão para tentar de novo.
class EstadoErro extends StatelessWidget {
  const EstadoErro({
    super.key,
    required this.mensagem,
    required this.aoRepetir,
  });

  final String mensagem;
  final VoidCallback aoRepetir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: estiloTexto(14, c: CoresApp.corpo, h: 1.45),
            ),
            const SizedBox(height: 12),
            BotaoContorno(
              'Tentar de novo',
              altura: 44,
              tamanhoFonte: 14,
              aoTocar: aoRepetir,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensagem para quando uma lista carregou mas não tem nada.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio(this.mensagem, {super.key});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: estiloTexto(14, c: CoresApp.atenuado, h: 1.45),
        ),
      ),
    );
  }
}

/// Os três estados de uma lista vinda da base: a carregar, erro com
/// "tentar de novo", e vazia. Só chama [construir] quando há elementos.
class VistaLista<T> extends StatelessWidget {
  const VistaLista({
    super.key,
    required this.valor,
    required this.aoRepetir,
    required this.mensagemVazia,
    required this.construir,
    this.aCarregar,
  });

  final AsyncValue<List<T>> valor;
  final VoidCallback aoRepetir;
  final String mensagemVazia;
  final Widget Function(List<T> lista) construir;

  /// O que mostrar enquanto carrega; por omissão, [EstadoCarregar].
  final Widget? aCarregar;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      loading: () => aCarregar ?? const EstadoCarregar(),
      error: (erro, _) =>
          EstadoErro(mensagem: mensagemDe(erro), aoRepetir: aoRepetir),
      data: (lista) =>
          lista.isEmpty ? EstadoVazio(mensagemVazia) : construir(lista),
    );
  }
}
