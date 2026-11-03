import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';

/// O brilho do esqueleto: uma faixa clara que atravessa a peça de um lado
/// ao outro. É o único sinal de "carregando" do app — nada de rodinha
/// girando. Mostra a forma do que está por vir, ou de onde a ação está
/// acontecendo.
///
/// Com "reduzir movimento" ligado, a peça fica parada na cor de base.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  /// A forma do esqueleto. Só a silhueta importa: a cor é trocada pelo
  /// brilho.
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? context.colors.surfaceContainerHigh,
      highlightColor: highlightColor ?? context.colors.surfaceContainerLow,
      period: const Duration(milliseconds: 1600),
      enabled: !context.reduceMotion,
      child: child,
    );
  }

  /// As cores do esqueleto sobre fundo escuro de foto: a tela cheia, a
  /// câmera, um botão cheio.
  static ({Color base, Color highlight}) on(Color background) {
    final light = background.computeLuminance() > 0.5;
    final ink = light ? Colors.black : Colors.white;
    return (base: ink.withValues(alpha: 0.14), highlight: ink.withValues(alpha: 0.42));
  }
}

/// Esqueleto de carregamento — sempre preferível a um spinner: mostra
/// a forma do conteúdo que está por vir.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = Radii.brSm,
    this.circle = false,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final bool circle;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: circle ? height : width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : borderRadius,
        ),
      ),
    );
  }
}

/// Lista de cards fantasma.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.itemCount = 4, this.itemHeight = 92});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Numa `Column` de altura rígida, quatro cards de 96px estouram a
        // viewport do Chrome de celular — e isso é a primeira tela de toda
        // viagem. Quando há altura conhecida, o esqueleto mostra só o que cabe.
        var count = itemCount;
        if (constraints.hasBoundedHeight) {
          final fits = (constraints.maxHeight / (itemHeight + Gap.md)).floor();
          count = fits.clamp(1, itemCount);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: ShimmerBox(height: itemHeight, borderRadius: Radii.brLg),
            ),
          ),
        );
      },
    );
  }
}

/// O que aparece no lugar do rótulo de um botão enquanto a ação dele roda:
/// uma barra do tamanho de uma palavra, brilhando na cor do texto do botão.
class ButtonSkeleton extends StatelessWidget {
  const ButtonSkeleton({super.key, required this.color, this.width = 72});

  /// A cor do texto do botão.
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: ShimmerBox(
        width: width,
        height: 10,
        borderRadius: Radii.brPill,
        baseColor: color.withValues(alpha: 0.28),
        highlightColor: color.withValues(alpha: 0.75),
      ),
    );
  }
}

/// O ícone de uma ação que está rodando: um círculo do tamanho do ícone,
/// brilhando. Serve para botão de ícone (compartilhar, baixar, excluir).
class IconSkeleton extends StatelessWidget {
  const IconSkeleton({super.key, this.size = 20, this.color});

  /// A cor do ícone que ele substitui; sem ela, a do tema.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? context.colors.onSurfaceVariant;
    return Semantics(
      label: 'Carregando',
      child: ShimmerBox(
        circle: true,
        height: size,
        baseColor: ink.withValues(alpha: 0.22),
        highlightColor: ink.withValues(alpha: 0.7),
      ),
    );
  }
}

/// Barra de progresso em esqueleto. Com [value], o trecho já feito enche e
/// brilha; sem ele, a barra inteira brilha — trabalho sem medida, como
/// preparar o arquivo antes de enviar.
class ShimmerProgress extends StatelessWidget {
  const ShimmerProgress({super.key, this.value, this.height = 4, this.color});

  final double? value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? context.colors.primary;
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return ClipRRect(
      borderRadius: Radii.brPill,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.colors.surfaceContainerHigh),
            TweenAnimationBuilder<double>(
              tween: Tween(end: (value ?? 1).clamp(0.0, 1.0)),
              duration: duration,
              curve: Motion.smooth,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Skeleton(
                  baseColor: value == null ? fill.withValues(alpha: 0.25) : fill,
                  highlightColor: Color.lerp(fill, Colors.white, 0.55)!,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linhas de texto fantasma: o formato de um item de lista enquanto ele não
/// chega — ícone, título e uma linha menor.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key, this.leading = true});

  final bool leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          if (leading) ...[
            const ShimmerBox(height: 20, circle: true),
            Gap.hMd,
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.7, child: ShimmerBox(height: 12)),
                Gap.vSm,
                FractionallySizedBox(widthFactor: 0.45, child: ShimmerBox(height: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
