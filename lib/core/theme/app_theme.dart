import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final onSurface = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final faint = isDark ? AppColors.darkInkFaint : AppColors.inkFaint;
    final outline = isDark ? AppColors.darkOutline : AppColors.outline;
    final divider = isDark ? AppColors.darkDivider : AppColors.divider;
    final chip = isDark ? AppColors.darkChip : AppColors.chip;

    // O azul do que se toca, e o azul-noite do botão principal: dois
    // papéis, duas cores. No escuro os dois clareiam.
    final accent = isDark ? AppColors.darkSky : AppColors.sky;
    final accentSoft = isDark ? AppColors.darkSkySoft : AppColors.skySoft;
    final action = isDark ? AppColors.darkAction : AppColors.night;
    final onAction = isDark ? AppColors.darkBackground : Colors.white;

    // O véu atrás de diálogos e sheets: azul-noite, não cinza.
    final scrim = (isDark ? Colors.black : AppColors.night).withValues(alpha: isDark ? 0.6 : 0.42);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? AppColors.darkBackground : Colors.white,
      primaryContainer: accentSoft,
      onPrimaryContainer: onSurface,
      secondary: action,
      onSecondary: onAction,
      secondaryContainer: chip,
      onSecondaryContainer: onSurface,
      tertiary: AppColors.sun,
      onTertiary: AppColors.night,
      tertiaryContainer: isDark ? AppColors.darkSunSoft : AppColors.sunSoft,
      onTertiaryContainer: isDark ? AppColors.sun : AppColors.night,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surface,
      surfaceContainerLow: background,
      surfaceContainer: background,
      surfaceContainerHigh: chip,
      surfaceContainerHighest: chip,
      outline: outline,
      outlineVariant: divider,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      shadow: isDark ? Colors.black : AppColors.night,
      scrim: scrim,
    );

    final textTheme = AppTypography.textTheme(onSurface, muted);

    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.brMd);
    const buttonSize = Size(0, 44);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Gap.lg + 2);
    final buttonText = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    // Realce de hover e de toque: um véu da cor do texto do botão.
    WidgetStateProperty<Color?> overlay(Color base) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return base.withValues(alpha: 0.14);
          if (s.contains(WidgetState.hovered)) return base.withValues(alpha: 0.08);
          if (s.contains(WidgetState.focused)) return base.withValues(alpha: 0.10);
          return null;
        });

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      hoverColor: onSurface.withValues(alpha: 0.04),
      focusColor: accent.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      splashColor: accent.withValues(alpha: 0.08),
      iconTheme: IconThemeData(color: muted, size: 20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
        selectionHandleColor: accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(Radii.pill),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(muted.withValues(alpha: 0.35)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: onSurface, size: 20),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brLg,
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
          backgroundColor: action,
          foregroundColor: onAction,
          disabledBackgroundColor: chip,
          disabledForegroundColor: faint,
        ).copyWith(overlayColor: overlay(onAction)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
          backgroundColor: surface,
          foregroundColor: onSurface,
          shadowColor: Colors.transparent,
        ).copyWith(overlayColor: overlay(onSurface)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          foregroundColor: onSurface,
          side: BorderSide(color: outline),
          textStyle: buttonText,
        ).copyWith(overlayColor: overlay(onSurface)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: buttonShape,
          foregroundColor: accent,
          textStyle: buttonText,
        ).copyWith(overlayColor: overlay(accent)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: buttonShape, foregroundColor: muted)
            .copyWith(overlayColor: overlay(onSurface)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(buttonShape),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? action : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? onAction : onSurface,
          ),
        ),
        selectedIcon: const SizedBox.shrink(),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: action,
        foregroundColor: onAction,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: buttonShape,
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder(outline),
        enabledBorder: inputBorder(outline),
        disabledBorder: inputBorder(divider),
        focusedBorder: inputBorder(accent, 1.6),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        // O rótulo que sobe para a borda ganha o azul do foco enquanto o
        // campo está ativo: mostra onde o cursor está sem precisar procurar.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((s) {
          final base = textTheme.bodyMedium!;
          if (s.contains(WidgetState.error)) return base.copyWith(color: AppColors.danger);
          if (s.contains(WidgetState.focused)) {
            return base.copyWith(color: accent, fontWeight: FontWeight.w500);
          }
          return base.copyWith(color: onSurface);
        }),
        hintStyle: textTheme.bodyMedium?.copyWith(color: faint),
        helperStyle: textTheme.labelSmall,
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? accent : faint,
        ),
        suffixIconColor: faint,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentSoft : surface,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? accent : outline),
        ),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          color: onSurface,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: muted, size: 16),
        showCheckmark: false,
        checkmarkColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
        elevation: 0,
        pressElevation: 0,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.sun,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            color: s.contains(WidgetState.selected) ? onSurface : muted,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 20,
            color: s.contains(WidgetState.selected) ? AppColors.night : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.sun,
        indicatorShape: const RoundedRectangleBorder(borderRadius: Radii.brSm),
        selectedIconTheme: const IconThemeData(color: AppColors.night, size: 20),
        unselectedIconTheme: IconThemeData(color: muted, size: 20),
        selectedLabelTextStyle:
            textTheme.labelSmall!.copyWith(color: onSurface, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: textTheme.labelSmall!.copyWith(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: outline,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: scrim,
        elevation: 12,
        shadowColor: (isDark ? Colors.black : AppColors.night).withValues(alpha: isDark ? 0.6 : 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brXl,
          // No escuro a sombra some no fundo; a borda separa o diálogo.
          side: isDark ? BorderSide(color: outline) : BorderSide.none,
        ),
        titleTextStyle: textTheme.headlineSmall,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brXl,
          side: BorderSide(color: outline),
        ),
        dayShape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Radii.brSm),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brXl,
          side: BorderSide(color: outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: (isDark ? Colors.black : AppColors.night).withValues(alpha: isDark ? 0.6 : 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brLg,
          side: BorderSide(color: outline),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(10),
          shadowColor: WidgetStatePropertyAll(
            (isDark ? Colors.black : AppColors.night).withValues(alpha: isDark ? 0.6 : 0.22),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brLg, side: BorderSide(color: outline)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: onSurface,
        elevation: 0,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: surface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
        insetPadding: const EdgeInsets.all(Gap.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: onSurface, borderRadius: Radii.brSm),
        textStyle: textTheme.labelSmall?.copyWith(color: surface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: chip,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colorScheme.onPrimary : faint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : chip,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        side: BorderSide(color: faint, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : faint,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: muted,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: accent,
        dividerColor: divider,
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        titleTextStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: muted,
      ),
    );
  }
}
