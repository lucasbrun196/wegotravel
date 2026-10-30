import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Barra de progresso chapada que enche com uma curva longa e suave. Na
/// ponta vai um fio mais claro, como o rastro de um avião, que some quando
/// a barra termina de encher.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.duration = Motion.reveal,
  });

  /// Fração de 0 a 1.
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;

  /// Cor conforme a barra se aproxima de 100%: céu no caminho, verde do mar
  /// quando completa.
  static Color colorFor(double fraction) =>
      fraction >= 0.999 ? AppColors.success : AppColors.sky;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final base = color ?? context.colors.primary;
    final radius = BorderRadius.circular(height);

    return Semantics(
      value: '${(target * 100).round()}%',
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(color: backgroundColor ?? context.colors.surfaceContainerHigh),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: context.reduceMotion ? Duration.zero : duration,
                curve: Motion.enter,
                builder: (context, v, _) {
                  // O rastro só existe enquanto a barra anda.
                  final moving = (target - v).abs() > 0.002;
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: base, borderRadius: radius),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          opacity: moving ? 1 : 0,
                          duration: Motion.normal,
                          child: Container(
                            width: height * 1.5,
                            decoration: BoxDecoration(
                              color: Color.lerp(base, Colors.white, 0.45),
                              borderRadius: radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
