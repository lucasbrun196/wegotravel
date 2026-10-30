import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Estado vazio: o ícone flutuando num círculo de céu claro, o que falta e
/// o botão para resolver.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Cor do círculo; sem ela, o azul do céu.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.colors.primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Floating(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(
                      color.withValues(alpha: context.isDark ? 0.22 : 0.12),
                      context.colors.surface,
                    ),
                  ),
                  child: Icon(icon, size: 30, color: color),
                ),
              ),
              Gap.vLg,
              Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
              Gap.vXs,
              Text(message, style: context.text.bodySmall, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                Gap.vLg,
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sobe e desce 5px num ciclo de 4 segundos, para o vazio não parecer
/// travado.
class _Floating extends StatefulWidget {
  const _Floating({required this.child});

  final Widget child;

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -5 * Curves.easeInOutSine.transform(_controller.value)),
        child: child,
      ),
    );
  }
}

/// Estado de erro com opção de tentar de novo.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.details});

  final String message;
  final String? details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 24, color: AppColors.danger),
              Gap.vMd,
              Text(message, style: context.text.titleMedium, textAlign: TextAlign.center),
              if (details != null) ...[
                Gap.vXs,
                Text(
                  details!,
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (onRetry != null) ...[
                Gap.vLg,
                OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
