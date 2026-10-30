import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import 'trip_countdown.dart';

/// A viagem como um dia de sol: ele nasce no primeiro dia, cruza o céu e
/// se põe no último. Antes da partida aparece só a ponta dele no horizonte,
/// à esquerda; depois do fim, à direita. O caminho já percorrido fica
/// cheio; o que falta, tracejado.
///
/// Quando a tela abre, o sol sobe do horizonte e corre até o dia de hoje —
/// o movimento de abertura do Resumo. Parado com "reduzir movimento".
class TripArc extends StatelessWidget {
  const TripArc({super.key, required this.trip, this.height = 92});

  final Trip trip;
  final double height;

  /// Onde o sol para: fração do caminho (0 a 1) e quanto ele fica abaixo
  /// do horizonte, em raios.
  (double, double) get _target {
    if (trip.isUpcoming) return (0, 0.3);
    if (trip.isFinished) return (1, 0.3);
    return (((trip.currentDay - 0.5) / trip.totalDays).clamp(0.0, 1.0), 0);
  }

  @override
  Widget build(BuildContext context) {
    final (progress, depth) = _target;
    final muted = context.colors.onSurfaceVariant;
    final edges = AppTypography.numeric(size: 12.5, color: muted);

    return Semantics(
      label: 'Andamento da viagem: ${tripCountdownLabel(trip) ?? ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 1600),
              curve: Motion.enter,
              builder: (context, t, _) => CustomPaint(
                size: Size.infinite,
                painter: _ArcPainter(
                  // Nasce abaixo do horizonte (2 raios) e vai até o alvo.
                  progress: progress * t,
                  depth: 2 + (depth - 2) * t,
                  line: context.colors.outline,
                  trail: AppColors.sun,
                  days: trip.totalDays,
                ),
              ),
            ),
          ),
          Gap.vSm,
          Row(
            children: [
              Text(Fmt.dayMonth(trip.startDate!), style: edges),
              Expanded(
                child: Center(child: TripCountdown(trip: trip, style: context.text.labelMedium)),
              ),
              Text(Fmt.dayMonth(trip.endDate!), style: edges),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.depth,
    required this.line,
    required this.trail,
    required this.days,
  });

  final double progress;
  final double depth;
  final Color line;
  final Color trail;
  final int days;

  static const _sun = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height - 2;
    const inset = _sun + 4;
    final left = inset;
    final right = size.width - inset;
    final rx = (right - left) / 2;
    final ry = horizon - _sun - 6;
    final center = Offset(left + rx, horizon);

    // Ponto do arco para uma fração do caminho, da esquerda para a direita.
    Offset at(double f) {
      final a = math.pi * (1 - f);
      return Offset(center.dx + rx * math.cos(a), center.dy - ry * math.sin(a));
    }

    final arcRect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    // O tracejado do caminho inteiro.
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const steps = 48;
    for (var i = 0; i < steps; i += 2) {
      final a0 = math.pi + math.pi * i / steps;
      final a1 = math.pi + math.pi * (i + 1) / steps;
      canvas.drawArc(arcRect, a0, a1 - a0, false, dash);
    }

    // O trecho já percorrido, cheio.
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        math.pi,
        math.pi * progress,
        false,
        Paint()
          ..color = trail.withValues(alpha: 0.85)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Um tique por dia no horizonte, quando cabem sem embolar.
    final tick = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    if (days > 1 && days <= 31 && (right - left) / days >= 8) {
      for (var d = 1; d < days; d++) {
        final x = left + (right - left) * d / days;
        canvas.drawLine(Offset(x, horizon - 3), Offset(x, horizon + 1), tick);
      }
    }
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), tick..strokeWidth = 1.5);

    // O sol, com um halo, cortado no horizonte.
    final p = at(progress);
    final sun = Offset(p.dx, p.dy + depth * _sun);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    canvas.drawCircle(sun, _sun + 6, Paint()..color = trail.withValues(alpha: 0.22));
    canvas.drawCircle(sun, _sun, Paint()..color = trail);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.depth != depth ||
      old.line != line ||
      old.trail != trail ||
      old.days != days;
}
