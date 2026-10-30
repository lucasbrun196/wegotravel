import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Cartão base do app: superfície, borda de 1px, cantos [Radii.lg].
///
/// Em repouso é chapado, sem sombra: a borda basta para separar do fundo.
/// Quando é interativo e o mouse passa por cima, ele sobe 2px, ganha uma
/// sombra azul-noite e a borda se tinge de azul; ao ser pressionado,
/// encolhe 1%. Os três juntos dizem "isto é clicável" sem precisar de
/// ícone.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.color,
    this.borderColor,
    this.borderRadius = Radii.brLg,
    this.accent,
    this.showShadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadius borderRadius;

  /// Mantido por compatibilidade: a cor de categoria não tinge o cartão.
  final Color? accent;

  /// Desliga a sombra do hover — para cartões dentro de outros.
  final bool showShadow;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final lifted = interactive && _hovered && !context.reduceMotion;
    final border = widget.borderColor ?? context.colors.outline;

    Widget content = AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.enter,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: widget.color ?? context.colors.surface,
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: lifted ? context.colors.primary.withValues(alpha: 0.5) : border,
        ),
        boxShadow: widget.showShadow && lifted ? AppColors.lift(dark: context.isDark) : const [],
      ),
      // O `Material` é filho do container para o realce do toque ficar
      // **por cima** do fundo do cartão — o do cartão inteiro e o das linhas
      // clicáveis dentro dele. Sem ele, o `InkWell` de uma linha pinta no
      // `Material` da página, por baixo do cartão, e o realce só aparece nos
      // cantos arredondados, como uma sombra quadrada vazando.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: interactive
            ? InkWell(
                borderRadius: widget.borderRadius,
                onTap: widget.onTap,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                child: Padding(padding: widget.padding, child: widget.child),
              )
            : Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (!interactive) return content;

    content = AnimatedScale(
      scale: _pressed && !context.reduceMotion ? 0.99 : 1,
      duration: Motion.instant,
      curve: Motion.enter,
      child: content,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Só mouse de verdade. O Chrome de celular emite eventos de mouse
      // sintéticos ao tocar: o `onEnter` disparava, o `onExit` nunca vinha,
      // e o cartão ficava erguido para sempre.
      onEnter: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: content,
    );
  }
}
