import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get safePadding => MediaQuery.paddingOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Verde do mar: "pago", "quitada", "a receber".
  Color get success => isDark ? AppColors.darkSuccess : AppColors.success;
  Color get successSoft => isDark ? AppColors.darkSuccessSoft : AppColors.successSoft;

  /// Coral do fim de tarde: o que você deve. Atenção, não erro.
  Color get debt => isDark ? AppColors.darkCoral : AppColors.coral;
  Color get debtSoft => isDark ? AppColors.darkCoralSoft : AppColors.coralSoft;

  /// O sol marca o agora — hoje, a próxima atividade, a aba aberta. É o
  /// mesmo amarelo nos dois temas; texto por cima dele é sempre azul-noite.
  Color get sun => AppColors.sun;
  Color get sunSoft => isDark ? AppColors.darkSunSoft : AppColors.sunSoft;

  /// O fundo do botão principal: azul-noite no claro, céu claro no escuro.
  Color get action => isDark ? AppColors.darkAction : AppColors.night;
  Color get onAction => isDark ? AppColors.darkBackground : Colors.white;

  ScreenSize get breakpoint => Breakpoints.of(this);
  bool get isMobile => breakpoint == ScreenSize.mobile;
  bool get isTablet => breakpoint == ScreenSize.tablet;
  bool get isDesktop => breakpoint == ScreenSize.desktop || breakpoint == ScreenSize.wide;
  bool get isCompact => breakpoint == ScreenSize.mobile || breakpoint == ScreenSize.tablet;

  /// Mais estreito que [isMobile]: o celular onde nada cabe lado a lado.
  /// É o gatilho para empilhar campos, botões e ações de cabeçalho.
  bool get isNarrow => Breakpoints.isNarrow(this);

  /// Respeita a preferência de acessibilidade de reduzir animações.
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}
