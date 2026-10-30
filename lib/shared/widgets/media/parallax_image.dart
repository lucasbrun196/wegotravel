import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';

/// Ilustração que corre mais devagar que a página: enquanto a pessoa rola,
/// a imagem desliza dentro da própria moldura e dá profundidade sem mexer
/// no layout. Precisa estar dentro de um `Scrollable`; fora dele, ou com
/// "reduzir movimento" ligado, fica parada em [alignment].
///
/// Decorativa: fica fora da árvore de acessibilidade.
class ParallaxImage extends StatelessWidget {
  const ParallaxImage({
    super.key,
    required this.asset,
    this.alignment = Alignment.center,
    this.flipX = false,
  });

  final String asset;

  /// Onde a imagem descansa quando não há rolagem.
  final Alignment alignment;

  /// Espelha a imagem — para pôr o assunto do lado oposto ao texto.
  final bool flipX;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (flipX) image = Transform.flip(flipX: true, child: image);

    // No escuro a ilustração cheia de sol ofuscaria o resto da tela: ganha
    // um véu azul-noite leve, que baixa o brilho sem apagar as cores.
    if (context.isDark) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF0B1622).withValues(alpha: 0.18),
          BlendMode.srcATop,
        ),
        child: image,
      );
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || context.reduceMotion) {
      return SizedBox.expand(child: image);
    }

    return ClipRect(
      child: Flow(
        delegate: _ParallaxDelegate(
          scrollable: scrollable,
          frameContext: context,
          rest: alignment,
        ),
        children: [image],
      ),
    );
  }
}

class _ParallaxDelegate extends FlowDelegate {
  _ParallaxDelegate({
    required this.scrollable,
    required this.frameContext,
    required this.rest,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext frameContext;
  final Alignment rest;

  /// A imagem ganha 30% a mais de altura que a moldura: é a folga por onde
  /// ela desliza.
  static const _overscan = 1.3;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight * _overscan,
      );

  @override
  void paintChildren(FlowPaintingContext context) {
    final viewport = scrollable.context.findRenderObject() as RenderBox?;
    final frame = frameContext.findRenderObject() as RenderBox?;
    if (viewport == null || frame == null || !frame.hasSize) {
      context.paintChild(0);
      return;
    }

    // Posição do centro da moldura na tela, de 0 (topo) a 1 (base).
    final center = frame.localToGlobal(frame.size.center(Offset.zero), ancestor: viewport);
    final fraction = (center.dy / scrollable.position.viewportDimension).clamp(0.0, 1.0);

    // No meio da tela a imagem fica no repouso pedido; acima e abaixo ela
    // corre para o lado contrário da rolagem.
    final y = (rest.y + (fraction - 0.5) * 1.2).clamp(-1.0, 1.0);
    final childSize = context.getChildSize(0) ?? context.size;
    final rect = Alignment(0, y).inscribe(childSize, Offset.zero & context.size);

    context.paintChild(0, transform: Matrix4.translationValues(0, rect.top, 0));
  }

  @override
  bool shouldRepaint(_ParallaxDelegate old) =>
      scrollable != old.scrollable || frameContext != old.frameContext || rest != old.rest;
}
