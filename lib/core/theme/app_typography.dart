import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Fira Sans no app inteiro, inclusive nos números — uma humanista comum,
/// de leitura fácil em tela pequena, sem cara de terminal.
///
/// Escala de terça maior (×1,25) a partir de 14px. Títulos em 600–700 com
/// um aperto leve de 1% do tamanho; o texto corrido fica solto.
abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _heading(
    double size,
    Color color, {
    double height = 1.2,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.firaSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: -0.01 * size,
        color: color,
      );

  static TextStyle _body(double size, Color color,
          {FontWeight weight = FontWeight.w400, double height = 1.5}) =>
      GoogleFonts.firaSans(fontSize: size, fontWeight: weight, height: height, color: color);

  static TextTheme textTheme(Color onSurface, Color muted) {
    return TextTheme(
      displayLarge: _heading(46, onSurface, height: 1.05, weight: FontWeight.w700),
      displayMedium: _heading(37, onSurface, height: 1.08, weight: FontWeight.w700),
      displaySmall: _heading(30, onSurface, height: 1.12, weight: FontWeight.w700),
      headlineLarge: _heading(26, onSurface, height: 1.15, weight: FontWeight.w700),
      headlineMedium: _heading(23, onSurface, height: 1.2),
      headlineSmall: _heading(19, onSurface, height: 1.3),
      titleLarge: _heading(16.5, onSurface, height: 1.35),
      titleMedium: _heading(15, onSurface, height: 1.4),
      titleSmall: _heading(14, onSurface, height: 1.4),
      bodyLarge: _body(15, onSurface, height: 1.55),
      bodyMedium: _body(14, onSurface),
      bodySmall: _body(13, muted, height: 1.45),
      labelLarge: _body(14, onSurface, weight: FontWeight.w500, height: 1.3),
      labelMedium: _body(12.5, muted, weight: FontWeight.w500, height: 1.3),
      labelSmall: _body(12, muted, height: 1.3),
    );
  }

  /// Valores em dinheiro: algarismos tabulares, para as colunas não
  /// "dançarem" quando o valor muda.
  static TextStyle money({double size = 24, FontWeight weight = FontWeight.w600, Color? color}) =>
      numeric(size: size, weight: weight, color: color);

  /// Horários, datas curtas, contadores — qualquer número em coluna.
  static TextStyle numeric({double size = 13, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.firaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        letterSpacing: size >= 24 ? -0.01 * size : 0,
        fontFeatures: _tabular,
      );
}
