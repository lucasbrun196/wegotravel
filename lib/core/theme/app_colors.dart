import 'package:flutter/material.dart';

/// Paleta alegre: um vermelho suave (coral) como destaque, pêssego de
/// apoio e cores de categoria em tons pastel vivos, sobre um branco quente.
///
/// Os nomes vêm da primeira paleta do app (coral, sunset, turquoise...) e
/// foram mantidos de propósito: são usados no app inteiro. `coral` é o
/// destaque, seja qual for a cor dele.
abstract final class AppColors {
  // Destaque: vermelho suave, nunca saturado a ponto de parecer alerta.
  static const coral = Color(0xFFE5665E);
  static const coralSoft = Color(0xFFFDECEA);

  /// Borda dos blocos tingidos de destaque.
  static const coralBorder = Color(0xFFF6CDC8);

  // Apoio e categorias — pastel, mas com cor de verdade.
  static const sunset = Color(0xFFF29E5C);
  static const sunsetSoft = Color(0xFFFFF0E3);
  static const turquoise = Color(0xFF3FB5A6);
  static const turquoiseSoft = Color(0xFFE2F5F2);
  static const deepSea = Color(0xFF3F6F96);
  static const sand = Color(0xFFFBF1EC);
  static const palm = Color(0xFF5DB37A);
  static const sky = Color(0xFF5B9FE0);
  static const grape = Color(0xFF9B83D9);

  // Neutros quentes
  static const ink = Color(0xFF2B201E);
  static const inkMuted = Color(0xFF7B6A66);
  static const inkFaint = Color(0xFFA59490);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFF9F6);
  static const outline = Color(0xFFF0E3DE);

  /// Divisória entre as linhas de uma lista — mais clara que a borda.
  static const divider = Color(0xFFF7EDE9);

  /// Fundo de chip, de aba no hover e de trilho de progresso.
  static const chip = Color(0xFFFAEEEA);

  // Tema escuro, também quente: um marrom muito escuro em vez de cinza.
  static const darkBackground = Color(0xFF171211);
  static const darkSurface = Color(0xFF211A19);
  static const darkOutline = Color(0xFF3A2E2C);
  static const darkDivider = Color(0xFF2C2321);
  static const darkChip = Color(0xFF2E2422);
  static const darkInk = Color(0xFFF6ECE9);
  static const darkInkMuted = Color(0xFFB4A29E);
  static const darkAccent = Color(0xFFF2857D);
  static const darkAccentSoft = Color(0xFF3A2220);

  // Semânticas. "Pago" é verde-menta, separado do destaque vermelho.
  static const success = Color(0xFF3FA772);
  static const successSoft = Color(0xFFE3F5EA);
  static const darkSuccess = Color(0xFF6CCB98);
  static const darkSuccessSoft = Color(0xFF1C2E24);
  static const warning = Color(0xFFE39A2F);
  static const danger = Color(0xFFC9413A);

  // Avisos flutuantes (`AppToast`). Saturados de propósito, para saltar
  // sobre qualquer tela, no tema claro e no escuro. O verde e o amarelo
  // levam texto escuro: com branco, o verde não passa de 2,3:1.
  static const toastSuccess = Color(0xFF22C55E);
  static const toastOnSuccess = Color(0xFF052E16);
  static const toastError = Color(0xFFE5252A);
  static const toastOnError = Color(0xFFFFFFFF);
  static const toastWarning = Color(0xFFFACC15);
  static const toastOnWarning = Color(0xFF1F1A00);

  // Gradientes
  static const sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, sunset],
  );

  static const oceanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [turquoise, sky],
  );

  static const twilightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [grape, coral],
  );

  static const tropicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palm, turquoise],
  );

  /// Sombra tingida, para o que deve "brilhar" (botão principal, cartão
  /// em destaque). Fraca por padrão: é um halo, não um holofote.
  static List<BoxShadow> glow(Color color, {double opacity = 0.22, double blur = 20, double y = 8}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
        ),
      ];

  /// Sombra de repouso dos cartões: quase imperceptível, só tira o cartão
  /// do chão.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  /// A sombra de quando um cartão é apontado pelo mouse: um pouco tingida
  /// de coral no claro, preta e mais densa no escuro.
  static List<BoxShadow> lift({required bool dark}) => [
        BoxShadow(
          color: (dark ? Colors.black : coral).withValues(alpha: dark ? 0.5 : 0.14),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}
