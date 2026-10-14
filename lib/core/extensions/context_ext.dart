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

  /// Verde de "pago", "quitada", "a receber". Separado do destaque, que é
  /// vermelho: com um só, "quitada" se leria como erro.
  Color get success => isDark ? AppColors.darkSuccess : AppColors.success;
  Color get successSoft => isDark ? AppColors.darkSuccessSoft : AppColors.successSoft;

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
