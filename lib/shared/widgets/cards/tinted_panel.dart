import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Painel de destaque chapado: o tom claro de uma cor de papel, com a borda
/// um pouco mais escura que o fundo. Para o número que pede atenção — o
/// "Você deve" das Contas.
///
/// A cor do fundo muda com animação: quando a dívida zera, o painel passa
/// do coral para o verde do mar em vez de trocar de repente.
class TintedPanel extends StatelessWidget {
  const TintedPanel({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.borderRadius = Radii.brXl,
  });

  final Widget child;

  /// O tom claro do fundo (`context.debtSoft`, `context.successSoft`...).
  final Color color;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final edge = Color.lerp(color, Theme.of(context).colorScheme.onSurface, 0.08)!;

    return AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : Motion.slow,
      curve: Motion.smooth,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: edge),
      ),
      child: child,
    );
  }
}
