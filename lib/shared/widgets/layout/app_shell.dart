import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/destinations.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/brand_mark.dart';
import '../domain/member_avatar.dart';
import '../effects/theme_toggle.dart';

/// Casca de navegação adaptativa.
///
/// A navegação mora no azul-noite, como a sinalização de um aeroporto, e a
/// aba aberta ganha a marca amarela do sol. A partir do tablet é uma barra
/// no alto com as abas; no celular as abas descem para uma barra embaixo,
/// e no alto fica só a viagem (toque para trocar) e a conta.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.tripName,
    this.onExit,
    this.userInitials,
    this.onAccount,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? tripName;

  /// Voltar para a lista de viagens.
  final VoidCallback? onExit;

  /// Iniciais da conta logada, no avatar do canto.
  final String? userInitials;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    // A barra de cima já respeitou o entalhe da tela; a página embaixo dela
    // não pode somar a mesma folga de novo.
    final body = MediaQuery.removePadding(context: context, removeTop: true, child: child);

    if (context.isMobile) {
      return Scaffold(
        body: Column(
          children: [
            _MobileTopBar(
              tripName: tripName ?? 'Viagem',
              onExit: onExit,
              userInitials: userInitials,
              onAccount: onAccount,
            ),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          currentIndex: currentIndex,
          onSelected: onDestinationSelected,
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            currentIndex: currentIndex,
            onSelected: onDestinationSelected,
            tripName: tripName,
            onExit: onExit,
            userInitials: userInitials,
            onAccount: onAccount,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// O azul da navegação: azul-noite no claro, a superfície no escuro (o
/// azul-noite sumiria no fundo).
Color _barColor(BuildContext context) => context.isDark ? AppColors.darkSurface : AppColors.night;

const _onBar = Colors.white;
const _onBarMuted = Color(0xFFA9BCCF);

// ---------------------------------------------------------------------------
// Celular
// ---------------------------------------------------------------------------

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.tripName,
    this.onExit,
    this.userInitials,
    this.onAccount,
  });

  final String tripName;
  final VoidCallback? onExit;
  final String? userInitials;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.md, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TripSwitcher(name: tripName, onTap: onExit, onDark: false),
                  ),
                ),
                if (userInitials != null) ...[
                  Gap.hSm,
                  _AccountAvatar(initials: userInitials!, onTap: onAccount, onDark: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior do celular. A aba aberta ganha uma pílula amarela atrás
/// do ícone, que se alarga quando a aba é escolhida.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _barColor(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: context.isDark
              ? Border(top: BorderSide(color: context.colors.outline))
              : null,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (i, d) in AppDestination.values.indexed)
                  Expanded(
                    child: _BottomItem(
                      destination: d,
                      selected: i == currentIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.destination, required this.selected, required this.onTap});

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Motion.spring,
              padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.sun : Colors.transparent,
                borderRadius: Radii.brPill,
              ),
              child: Icon(
                destination.icon,
                size: 20,
                color: selected ? AppColors.night : _onBarMuted,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: context.text.labelSmall!.copyWith(
                fontSize: 11.5,
                color: selected ? _onBar : _onBarMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet e computador
// ---------------------------------------------------------------------------

/// Barra superior: a viagem à esquerda, as abas no centro e, à direita, o
/// tema e a conta.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentIndex,
    required this.onSelected,
    this.tripName,
    this.onExit,
    this.userInitials,
    this.onAccount,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final String? tripName;
  final VoidCallback? onExit;
  final String? userInitials;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _barColor(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: context.isDark
              ? Border(bottom: BorderSide(color: context.colors.outline))
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Row(
                children: [
                  // Os dois lados com o mesmo `flex`: é o que deixa as abas
                  // exatamente no centro, seja qual for o nome da viagem.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _TripSwitcher(name: tripName ?? 'Viagem', onTap: onExit, onDark: true),
                    ),
                  ),
                  _Tabs(currentIndex: currentIndex, onSelected: onSelected),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Theme(
                          data: context.theme.copyWith(
                            iconButtonTheme: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                foregroundColor: _onBarMuted,
                                hoverColor: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          child: const ThemeToggle(),
                        ),
                        if (userInitials != null) ...[
                          Gap.hSm,
                          _AccountAvatar(initials: userInitials!, onTap: onAccount, onDark: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// As abas em texto, com a marca amarela embaixo da aberta. A marca desliza
/// de uma aba para a outra. As abas têm largura fixa: é o que permite a
/// marca saber onde parar sem medir texto.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _markWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    const destinations = AppDestination.values;
    final tabWidth = context.isTablet ? 90.0 : 106.0;

    return SizedBox(
      width: tabWidth * destinations.length,
      height: 64,
      child: Stack(
        children: [
          Row(
            children: [
              for (final (i, d) in destinations.indexed)
                _Tab(
                  destination: d,
                  width: tabWidth,
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
          AnimatedPositioned(
            duration: context.reduceMotion ? Duration.zero : Motion.slow,
            curve: Motion.spring,
            left: tabWidth * currentIndex + (tabWidth - _markWidth) / 2,
            bottom: 8,
            width: _markWidth,
            height: 3,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.sun, borderRadius: Radii.brPill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.destination,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected || _hovered ? _onBar : _onBarMuted;

    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        width: widget.width,
        height: 64,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hovered = v),
          hoverColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.06),
          focusColor: Colors.white.withValues(alpha: 0.10),
          borderRadius: Radii.brMd,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: context.text.labelLarge!.copyWith(
                fontSize: 14,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(
                widget.destination.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Peças comuns
// ---------------------------------------------------------------------------

/// O selo da marca e o nome da viagem. Leva de volta à lista de viagens.
class _TripSwitcher extends StatefulWidget {
  const _TripSwitcher({required this.name, required this.onDark, this.onTap});

  final String name;
  final VoidCallback? onTap;

  /// Sobre a barra azul-noite (texto claro) ou sobre o fundo da página.
  final bool onDark;

  @override
  State<_TripSwitcher> createState() => _TripSwitcherState();
}

class _TripSwitcherState extends State<_TripSwitcher> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final onDark = widget.onDark;
    final text = onDark ? _onBar : context.colors.onSurface;
    final soft = onDark ? _onBarMuted : context.colors.onSurfaceVariant;
    final hoverFill = onDark
        ? Colors.white.withValues(alpha: 0.08)
        : context.colors.surfaceContainerHigh;

    return Tooltip(
      message: 'Trocar de viagem',
      child: Semantics(
        button: true,
        label: 'Viagem ${widget.name}. Trocar de viagem',
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (e) {
            if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
          },
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.fromLTRB(6, 6, Gap.md, 6),
              decoration: BoxDecoration(
                color: _hovered ? hoverFill : Colors.transparent,
                borderRadius: Radii.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SunMark(
                    size: 30,
                    // Sobre a barra azul-noite, o selo clareia um tom para
                    // não se fundir com ela.
                    tile: onDark ? AppColors.nightRaised : null,
                  ),
                  Gap.hMd,
                  Flexible(
                    child: Text(
                      widget.name,
                      style: context.text.titleMedium?.copyWith(color: text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Gap.hXs,
                  AnimatedRotation(
                    turns: _hovered ? 0.5 : 0,
                    duration: Motion.normal,
                    curve: Motion.enter,
                    child: Icon(Icons.unfold_more_rounded, size: 16, color: soft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O avatar da conta. No hover ganha um anel amarelo.
class _AccountAvatar extends StatefulWidget {
  const _AccountAvatar({required this.initials, required this.onDark, this.onTap});

  final String initials;
  final bool onDark;
  final VoidCallback? onTap;

  @override
  State<_AccountAvatar> createState() => _AccountAvatarState();
}

class _AccountAvatarState extends State<_AccountAvatar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ring = _hovered
        ? AppColors.sun
        : widget.onDark
            ? Colors.white.withValues(alpha: 0.18)
            : context.colors.outline;

    return Tooltip(
      message: 'Sua conta',
      child: Semantics(
        button: true,
        label: 'Sua conta',
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (e) {
            if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
          },
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: Motion.normal,
              curve: Motion.enter,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 2),
              ),
              child: widget.onDark
                  ? InitialsAvatar(
                      initials: widget.initials,
                      size: 30,
                      background: AppColors.darkAction,
                      foreground: AppColors.night,
                    )
                  : InitialsAvatar(initials: widget.initials, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
