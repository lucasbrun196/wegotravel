import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/member.dart';

/// Avatar do participante: as iniciais do nome sobre um tom suave da cor
/// dele — cada pessoa da turma tem a sua.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 32,
    this.selected = false,
    this.showBorder = true,
  });

  final Member member;
  final double size;
  final bool selected;

  /// Mantido por compatibilidade: o anel aparece só quando selecionado.
  final bool showBorder;

  @override
  Widget build(BuildContext context) => InitialsAvatar(
        initials: member.initials,
        size: size,
        selected: selected,
        color: member.color,
      );
}

/// O círculo de iniciais, para quem não é `Member` — a conta logada, por
/// exemplo. Sem [color], usa o azul do céu.
///
/// Fundo chapado: o tom claro da cor da pessoa, já misturado à superfície,
/// para o círculo ficar igual sobre qualquer fundo.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 32,
    this.selected = false,
    this.color,
    this.background,
    this.foreground,
  });

  final String initials;
  final double size;
  final bool selected;
  final Color? color;

  /// Fundo e texto explícitos, para fundos que não são a superfície — a
  /// barra azul-noite, por exemplo.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.sky;
    final dark = context.isDark;
    final fill = background ??
        Color.alphaBlend(base.withValues(alpha: dark ? 0.30 : 0.16), context.colors.surface);
    final fg = foreground ??
        (dark ? Color.lerp(base, Colors.white, 0.45)! : Color.lerp(base, Colors.black, 0.3)!);

    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.enter,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: selected ? Border.all(color: base, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: context.text.labelSmall?.copyWith(
          // 11px no tamanho padrão; acompanha o círculo quando ele cresce.
          fontSize: size <= 36 ? 11 : size * 0.3,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}

/// Avatar + nome, na horizontal.
class MemberChip extends StatelessWidget {
  const MemberChip({
    super.key,
    required this.member,
    this.selected = false,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  final Member member;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = member.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.brPill,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.enter,
          padding: const EdgeInsets.fromLTRB(4, 4, Gap.md, 4),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: context.isDark ? 0.22 : 0.12)
                : context.colors.surface,
            borderRadius: Radii.brPill,
            border: Border.all(
              color: selected ? color : context.colors.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar(member: member, size: 26),
              Gap.hSm,
              // `Flexible` porque o chip vive dentro de `Wrap`/`Row`: sem
              // isso um nome longo empurra o chip para fora da tela.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.shortName,
                      style: context.text.labelLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[Gap.hSm, trailing!],
              AnimatedSwitcher(
                duration: Motion.normal,
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: selected
                    ? Padding(
                        key: const ValueKey(true),
                        padding: const EdgeInsets.only(left: Gap.xs),
                        child: Icon(Icons.check_rounded, size: 16, color: color),
                      )
                    : const SizedBox.shrink(key: ValueKey(false)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
