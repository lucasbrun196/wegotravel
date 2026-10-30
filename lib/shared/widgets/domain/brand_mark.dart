import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';

/// A marca do app: o selo do sol se pondo no mar e o nome "WeGoTravel".
/// Fica na splash, no login e na página de erro.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.color, this.rise = 1, this.tile});

  /// Tamanho do nome. O selo acompanha.
  final double size;

  /// Cor do nome; sem ela, a do texto.
  final Color? color;

  /// Quanto o sol do selo já subiu, de 0 a 1 — a splash anima isto.
  final double rise;

  /// Fundo do selo; ver [SunMark.tile].
  final Color? tile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WeGoTravel',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SunMark(size: size * 1.2, rise: rise, tile: tile),
          SizedBox(width: size * 0.36),
          Text(
            'WeGoTravel',
            style: context.text.displaySmall?.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02 * size,
              height: 1,
              color: color ?? context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// O selo: um quadrado azul-noite com o sol meio afundado no horizonte e o
/// reflexo dele na água. Desenhado, e não imagem, para ficar nítido de 16px
/// a 160px e poder subir na splash.
class SunMark extends StatelessWidget {
  const SunMark({super.key, this.size = 32, this.rise = 1, this.tile});

  final double size;
  final double rise;

  /// Fundo do selo; sem ele, azul-noite.
  final Color? tile;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SunMarkPainter(
          rise: rise.clamp(0.0, 1.0),
          tile: tile ?? AppColors.night,
          // No escuro o selo azul-noite quase some no fundo: ganha um fio.
          edge: context.isDark ? AppColors.darkOutline : null,
        ),
      ),
    );
  }
}

class _SunMarkPainter extends CustomPainter {
  _SunMarkPainter({required this.rise, required this.tile, this.edge});

  final double rise;
  final Color tile;
  final Color? edge;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final tileRect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26));
    canvas.drawRRect(tileRect, Paint()..color = tile);
    if (edge != null) {
      canvas.drawRRect(
        tileRect.deflate(0.5),
        Paint()
          ..color = edge!
          ..style = PaintingStyle.stroke,
      );
    }

    final horizon = s * 0.6;
    final radius = s * 0.23;
    final center = Offset(s / 2, horizon + radius * (1 - rise) * 1.1);

    // O sol só aparece acima da linha do mar.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, s, horizon));
    canvas.drawCircle(center, radius, Paint()..color = AppColors.sun);
    canvas.restore();

    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, s * 0.05);

    canvas.drawLine(
      Offset(s * 0.18, horizon),
      Offset(s * 0.82, horizon),
      line..color = AppColors.darkSky,
    );

    // O reflexo encolhe com o sol: some quando ele ainda não nasceu.
    final glint = line..color = AppColors.sun.withValues(alpha: 0.75 * rise);
    canvas.drawLine(Offset(s * 0.33, s * 0.72), Offset(s * 0.67, s * 0.72), glint);
    canvas.drawLine(Offset(s * 0.42, s * 0.82), Offset(s * 0.58, s * 0.82), glint);
  }

  @override
  bool shouldRepaint(_SunMarkPainter old) =>
      old.rise != rise || old.tile != tile || old.edge != edge;
}
