import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';

/// Selo de categoria: o ícone na cor dela, sobre o tom claro da mesma cor,
/// chapado. É o que dá cor às listas de contas e de atividades — e
/// identifica a categoria antes mesmo de ler o texto.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.faded = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Atividade cancelada ou concluída: o selo perde a cor.
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final base = faded ? context.colors.onSurfaceVariant : color;

    return AnimatedContainer(
      duration: Motion.normal,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        color: Color.alphaBlend(base.withValues(alpha: dark ? 0.24 : 0.14), context.colors.surface),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: dark ? Color.lerp(base, Colors.white, 0.3) : Color.lerp(base, Colors.black, 0.12),
      ),
    );
  }
}
