import 'package:flutter/material.dart';

/// A paleta sai das ilustrações do app: o azul-noite da fuselagem, o céu,
/// o sol, o mar raso e as nuvens do fim de tarde. Tudo chapado, como nos
/// pôsteres — degradê só onde uma imagem precisa de véu para o texto.
///
/// As cores de marca têm um papel cada:
/// - [night] é a tinta: texto, botão principal e a barra de navegação.
/// - [sky] é o que se toca: link, foco, seleção, progresso.
/// - [sun] marca o agora: hoje, a próxima atividade, a aba aberta. Texto
///   sobre ele é sempre [night].
/// - [success], o verde do mar, é pago, quitado, a receber.
/// - [coral] é o que você deve: pede atenção sem parecer erro.
/// - [danger] fica para erro e ação destrutiva.
///
/// As outras ([sunset], [turquoise], [deepSea], [palm], [plum]) são das
/// categorias, dos participantes e do clima.
abstract final class AppColors {
  // Marca
  static const night = Color(0xFF14283B);

  /// Um tom acima do azul-noite: o que precisa aparecer sobre a barra de
  /// navegação, como o selo da marca.
  static const nightRaised = Color(0xFF213C57);
  static const sky = Color(0xFF2C6AA8);
  static const skySoft = Color(0xFFE1ECF8);
  static const sun = Color(0xFFF2BF45);
  static const sunSoft = Color(0xFFFCF0D2);

  // Matizes das ilustrações. Escuros o bastante para virar ícone sobre o
  // próprio tom claro.
  static const coral = Color(0xFFC64C2E);
  static const coralSoft = Color(0xFFFBE7E1);
  static const sunset = Color(0xFFCF741B);
  static const sunsetSoft = Color(0xFFFDEEDB);
  static const turquoise = Color(0xFF1F9387);
  static const turquoiseSoft = Color(0xFFDDF2EF);
  static const deepSea = Color(0xFF2B5A8A);
  static const palm = Color(0xFF3A8354);
  static const plum = Color(0xFF8A5A84);
  static const sand = Color(0xFFF4E7CD);

  // Neutros claros: o branco de um céu limpo, puxado para o azul.
  static const ink = night;
  static const inkMuted = Color(0xFF546679);
  static const inkFaint = Color(0xFF8494A5);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF3F6F9);
  static const outline = Color(0xFFD8E1EA);

  /// Divisória entre as linhas de uma lista — mais clara que a borda.
  static const divider = Color(0xFFE6ECF2);

  /// Fundo de chip, de linha no hover e de trilho de progresso.
  static const chip = Color(0xFFEAF0F5);

  // Tema escuro: voo noturno. Azul muito fundo em vez de cinza.
  static const darkBackground = Color(0xFF0B1622);
  static const darkSurface = Color(0xFF112131);
  static const darkOutline = Color(0xFF223A52);
  static const darkDivider = Color(0xFF1A2E42);
  static const darkChip = Color(0xFF182C41);
  static const darkInk = Color(0xFFEAF0F6);
  static const darkInkMuted = Color(0xFFA3B4C6);
  static const darkInkFaint = Color(0xFF7A8DA2);
  static const darkSky = Color(0xFF8DBEEC);
  static const darkSkySoft = Color(0xFF17324D);
  static const darkSunSoft = Color(0xFF2B2A20);
  static const darkCoral = Color(0xFFF2876C);
  static const darkCoralSoft = Color(0xFF3A2420);

  /// O botão principal no escuro: céu claro com texto da cor do fundo.
  static const darkAction = Color(0xFF9CC5EE);

  // Semânticas.
  static const success = Color(0xFF11766B);
  static const successSoft = Color(0xFFDDF2EF);
  static const darkSuccess = Color(0xFF4CC4B4);
  static const darkSuccessSoft = Color(0xFF12332F);
  static const warning = Color(0xFF9A6210);
  static const danger = Color(0xFFC0362C);

  // Avisos flutuantes (`AppToast`): cheios, para saltar sobre qualquer
  // tela nos dois temas. O amarelo leva texto azul-noite; os outros, branco
  // (acima de 5:1 nos dois).
  static const toastSuccess = success;
  static const toastOnSuccess = Color(0xFFFFFFFF);
  static const toastError = danger;
  static const toastOnError = Color(0xFFFFFFFF);
  static const toastWarning = sun;
  static const toastOnWarning = night;

  /// A sombra de quando um cartão é apontado pelo mouse: tingida de
  /// azul-noite no claro, preta e mais densa no escuro. Nunca cinza.
  static List<BoxShadow> lift({required bool dark}) => [
        BoxShadow(
          color: (dark ? Colors.black : night).withValues(alpha: dark ? 0.45 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: (dark ? Colors.black : night).withValues(alpha: dark ? 0.25 : 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  /// O que flutua sobre a página: toast, menu, painel aberto.
  static List<BoxShadow> float({required bool dark}) => [
        BoxShadow(
          color: (dark ? Colors.black : night).withValues(alpha: dark ? 0.55 : 0.16),
          blurRadius: 32,
          offset: const Offset(0, 14),
        ),
      ];
}
