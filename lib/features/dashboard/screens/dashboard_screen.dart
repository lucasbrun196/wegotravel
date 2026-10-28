import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/destinations.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/itinerary_enums.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../data/models/member.dart';
import '../../../data/models/trip.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/category_badge.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/effects/grid_backdrop.dart';
import '../../../shared/widgets/feedback/animated_progress_bar.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/layout/stat_strip.dart';
import '../../expenses/controllers/money_controllers.dart';
import '../../expenses/widgets/bill_form_sheet.dart';
import '../../itinerary/widgets/itinerary_form_sheet.dart';

/// A partir desta largura o roteiro e o acerto ficam lado a lado.
const _twoColumns = 880.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider).valueOrNull;
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];

    return AppPage(
      title: trip?.name ?? '',
      header: trip == null ? null : _Hero(trip: trip, facts: _facts(trip, members.length)),
      children: [
        const _MoneyStrip(),
        Gap.vXl,
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _twoColumns) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_ItinerarySummary(), Gap.vXl, _SettlementPanel()],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _ItinerarySummary()),
                Gap.hXl,
                Expanded(flex: 2, child: _SettlementPanel()),
              ],
            );
          },
        ),
      ],
    );
  }

  /// "Florianópolis, SC · 27/12/2026 – 03/01/2027 · 4 participantes"
  static String _facts(Trip trip, int memberCount) => [
        if (trip.destination.isNotEmpty) trip.destination,
        if (trip.hasDates)
          '${Fmt.dateShortWithYear(trip.startDate!)} – ${Fmt.dateShortWithYear(trip.endDate!)}',
        if (memberCount > 0) '$memberCount ${memberCount == 1 ? "participante" : "participantes"}',
      ].join(' · ');
}

/// O topo do Resumo: a contagem, o nome da viagem e a linha de fatos sobre
/// o painel de grade.
class _Hero extends StatelessWidget {
  const _Hero({required this.trip, required this.facts});

  final Trip trip;
  final String facts;

  @override
  Widget build(BuildContext context) {
    return GridBackdrop(
      padding: EdgeInsets.all(context.isMobile ? Gap.xl : Gap.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountdownTag(trip: trip),
          Gap.vLg,
          Text(
            trip.name,
            style: context.isMobile ? context.text.headlineLarge : context.text.displayMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (facts.isNotEmpty) ...[
            Gap.vSm,
            Text(facts, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// A contagem da viagem numa etiqueta mono: "T–79 dias", "Dia 3/8".
class _CountdownTag extends StatelessWidget {
  const _CountdownTag({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final label = switch (trip) {
      _ when !trip.hasDates => null,
      _ when trip.daysUntilStart > 1 => 'T–${trip.daysUntilStart} dias',
      _ when trip.daysUntilStart == 1 => 'T–1 dia',
      _ when trip.isOngoing => 'Dia ${trip.currentDay}/${trip.totalDays}',
      _ => 'Concluída',
    };
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!trip.isFinished) ...[const _PulseDot(), Gap.hSm],
          Text(label, style: AppTypography.mono(size: 12, color: context.colors.onSurface)),
        ],
      ),
    );
  }
}

/// O ponto verde de "em andamento": pulsa devagar enquanto a viagem não
/// acabou. Parado quando o sistema pede menos movimento.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35 * t), blurRadius: 0, spreadRadius: 3 * t),
            ],
          ),
        );
      },
    );
  }
}

/// Total, Pago, Falta e Você deve, numa faixa só.
class _MoneyStrip extends ConsumerWidget {
  const _MoneyStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(moneyOverviewProvider);
    final pending = ref.watch(myPendingSharesProvider);
    final iOwe = pending.fold<int>(0, (sum, s) => sum + s.remainingCents);
    final next = pending.isEmpty ? null : pending.first;

    return StatStrip(
      cells: [
        StatCell.money(
          label: 'Total',
          color: AppColors.sky,
          cents: overview.totalCents,
          footnote: '${overview.billCount} ${overview.billCount == 1 ? "conta" : "contas"}',
        ),
        StatCell.money(
          label: 'Pago',
          color: AppColors.success,
          cents: overview.paidCents,
          footnote: Fmt.percent(overview.progress),
        ),
        StatCell.money(
          label: 'Falta',
          color: AppColors.sunset,
          cents: overview.pendingCents,
          footnote: '${overview.openBillCount} em aberto',
        ),
        StatCell.money(
          label: 'Você deve',
          color: AppColors.coral,
          cents: iOwe,
          highlight: true,
          footnote: next == null
              ? 'nada pendente'
              : [
                  'próx. ${Money.format(next.remainingCents)}',
                  if (next.dueDate != null) 'vence ${Fmt.dateShort(next.dueDate!)}',
                ].join(' · '),
        ),
      ],
    );
  }
}

/// O roteiro em resumo: a próxima atividade em destaque, uma linha por dia
/// para os próximos dias e, no rodapé, o tamanho do roteiro inteiro.
class _ItinerarySummary extends ConsumerWidget {
  const _ItinerarySummary();

  /// Bastante para dar a cara dos próximos dias sem virar o roteiro inteiro.
  static const _maxDays = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripId = ref.watch(currentTripIdProvider);
    final allDays = ref.watch(itineraryDaysProvider);
    final next = ref.watch(nextItineraryItemProvider);
    final today = DateTime.now().dateOnly;

    // Do dia de hoje em diante; com a viagem já encerrada, o roteiro todo.
    final upcoming = allDays.where((d) => !d.date.isBefore(today)).toList();
    final shown = (upcoming.isEmpty ? allDays : upcoming).take(_maxDays).toList();
    final empty = allDays.isEmpty;
    void open() => context.go(Routes.tripSection(tripId, AppDestination.itinerary));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Roteiro',
          actionLabel: empty ? null : 'Ver tudo',
          onAction: empty ? null : open,
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: empty
              ? _EmptyRow(
                  message: 'Nenhuma atividade no roteiro.',
                  actionLabel: 'Nova atividade',
                  onAction: () => showItineraryForm(context),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (next != null) ...[_NextUp(item: next), const Divider()],
                    for (final day in shown) _DayLine(day: day, onTap: open),
                    const Divider(),
                    _ItineraryFooter(days: allDays),
                  ],
                ),
        ),
      ],
    );
  }
}

/// "hoje", "amanhã" ou "sex 27/12".
String _relativeDay(DateTime date) {
  final days = date.dateOnly.difference(DateTime.now().dateOnly).inDays;
  return switch (days) {
    0 => 'hoje',
    1 => 'amanhã',
    _ => '${Fmt.weekdayShort(date)} ${Fmt.dateShort(date)}',
  };
}

/// A próxima atividade que ainda vai acontecer, numa faixa tingida com a
/// cor da categoria dela.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.category.color;
    final dark = context.isDark;
    final place = item.placeName ?? '';
    final when = [
      _relativeDay(item.date),
      if (item.hasTime) Fmt.time(item.startAt!),
    ].join(' · ');

    return Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: dark ? 0.16 : 0.10), color.withValues(alpha: 0)],
        ),
      ),
      child: InkWell(
        onTap: () => showItineraryForm(context, item: item),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              CategoryBadge(icon: item.category.icon, color: color, size: 44),
              Gap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRÓXIMA · ${when.toUpperCase()}',
                      style: AppTypography.mono(
                        size: 11,
                        weight: FontWeight.w600,
                        color: dark
                            ? Color.lerp(color, Colors.white, 0.25)
                            : Color.lerp(color, Colors.black, 0.25),
                      ),
                    ),
                    Gap.vXs,
                    Text(
                      item.title,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (place.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            item.hasCoords ? Icons.place : Icons.place_outlined,
                            size: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                          Gap.hXs,
                          Expanded(
                            child: Text(
                              place,
                              style: context.text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um dia numa linha só: a data em bloco, os nomes das atividades em
/// sequência e, embaixo, os ícones das categorias e a contagem.
class _DayLine extends StatelessWidget {
  const _DayLine({required this.day, required this.onTap});

  final ItineraryDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // As canceladas só entram quando o dia não tem mais nada.
    final active = day.items.where((i) => i.status != ItineraryStatus.cancelled).toList();
    final items = active.isEmpty ? day.items : active;
    final categories = {for (final i in items) i.category}.take(4);
    final firstTime = items.where((i) => i.hasTime).firstOrNull?.startAt;
    final allDone = day.doneCount == day.items.length;
    final muted = context.colors.onSurfaceVariant;

    final meta = [
      '${items.length} ${items.length == 1 ? "atividade" : "atividades"}',
      if (firstTime != null) 'desde ${Fmt.time(firstTime)}',
      if (day.doneCount > 0 && !allDone) '${day.doneCount} feitas',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: [
            _DateTile(date: day.date, today: day.isToday),
            Gap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.map((i) => i.title).join(' · '),
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: allDone ? muted : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap.vXs,
                  Row(
                    children: [
                      for (final c in categories) ...[
                        Icon(c.icon, size: 14, color: allDone ? muted : c.color),
                        const SizedBox(width: 2),
                      ],
                      Gap.hXs,
                      Expanded(
                        child: Text(
                          meta,
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap.hSm,
            allDone
                ? Icon(Icons.check_circle_rounded, size: 18, color: context.success)
                : Icon(Icons.chevron_right_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

/// A data como folha de calendário: dia da semana, número e mês. Hoje
/// ganha a cor de destaque.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.today});

  final DateTime date;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final strong = today ? context.colors.onPrimary : context.colors.onSurface;
    final soft =
        today ? context.colors.onPrimary.withValues(alpha: 0.8) : context.colors.onSurfaceVariant;
    final small = AppTypography.mono(size: 9, weight: FontWeight.w600, color: soft);

    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      decoration: BoxDecoration(
        color: today ? context.colors.primary : context.colors.surfaceContainerLow,
        borderRadius: Radii.brSm,
        border: Border.all(color: today ? context.colors.primary : context.colors.outline),
      ),
      child: Column(
        children: [
          Text((today ? 'hoje' : Fmt.weekdayShort(date)).toUpperCase(), style: small),
          Text(
            '${date.day}',
            style: AppTypography.mono(size: 17, weight: FontWeight.w600, color: strong)
                .copyWith(height: 1.15),
          ),
          Text(Fmt.monthShort(date).toUpperCase(), style: small),
        ],
      ),
    );
  }
}

/// O roteiro inteiro numa linha: quantas atividades, em quantos dias, e as
/// categorias que mais aparecem.
class _ItineraryFooter extends StatelessWidget {
  const _ItineraryFooter({required this.days});

  final List<ItineraryDay> days;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final d in days) ...d.items.where((i) => i.status != ItineraryStatus.cancelled),
    ];
    final done = items.where((i) => i.status == ItineraryStatus.done).length;
    final counts = <ItineraryCategory, int>{};
    for (final i in items) {
      counts.update(i.category, (n) => n + 1, ifAbsent: () => 1);
    }
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(context.isMobile ? 3 : 4);

    final summary = [
      '${items.length} ${items.length == 1 ? "atividade" : "atividades"} em '
          '${days.length} ${days.length == 1 ? "dia" : "dias"}',
      if (done > 0) '$done feitas',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Expanded(child: Text(summary, style: context.text.labelSmall)),
          for (final e in top) ...[
            Gap.hXs,
            Tooltip(
              message: e.key.label,
              child: _CategoryCount(category: e.key, count: e.value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma categoria e quantas vezes ela aparece no roteiro, numa pílula.
class _CategoryCount extends StatelessWidget {
  const _CategoryCount({required this.category, required this.count});

  final ItineraryCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = category.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.20 : 0.12),
        borderRadius: Radii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: AppTypography.mono(size: 11, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Quanto já foi pago e o saldo de cada um.
class _SettlementPanel extends ConsumerWidget {
  const _SettlementPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(moneyOverviewProvider);
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final balances = ref.watch(memberBalancesProvider);
    final uid = ref.watch(currentUidProvider);
    final budget = ref.watch(tripProvider).valueOrNull?.budgetCents ?? 0;
    final muted = context.colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Acerto'),
        GlassCard(
          padding: EdgeInsets.zero,
          child: overview.billCount == 0
              ? _EmptyRow(
                  message: 'Nenhuma conta cadastrada.',
                  actionLabel: 'Nova conta',
                  onAction: () => showBillForm(context),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProgressLine(
                            label: 'Pago',
                            value: overview.progress,
                            detail: '${Money.format(overview.paidCents)} de '
                                '${Money.format(overview.totalCents)}',
                          ),
                          if (budget > 0) ...[
                            Gap.vLg,
                            _ProgressLine(
                              label: 'Orçamento',
                              value: overview.totalCents / budget,
                              detail: '${Money.format(overview.totalCents)} de '
                                  '${Money.format(budget)}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(),
                    for (final (i, member) in members.indexed) ...[
                      if (i > 0) const Divider(),
                      _BalanceRow(
                        member: member,
                        cents: balances[member.id] ?? 0,
                        isMe: member.id == uid,
                      ),
                    ],
                    if (members.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                        child: Text('+ a receber   − a pagar',
                            style: context.text.labelSmall?.copyWith(color: muted)),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value, required this.detail});

  final String label;
  final double value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleSmall)),
            Text(
              Fmt.percent(value),
              style: AppTypography.mono(size: 13, color: context.colors.onSurface),
            ),
          ],
        ),
        Gap.vSm,
        AnimatedProgressBar(value: value, height: 8),
        Gap.vSm,
        Text(detail, style: AppTypography.mono(size: 12, color: context.colors.onSurfaceVariant)),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.member, required this.cents, required this.isMe});

  final Member member;
  final int cents;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (cents) {
      > 0 => ('+${Money.format(cents)}', context.success),
      < 0 => ('−${Money.format(-cents)}', context.colors.onSurface),
      _ => (Money.format(0), context.colors.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
      child: Row(
        children: [
          MemberAvatar(member: member, size: 24),
          Gap.hMd,
          Expanded(
            child: Text(
              isMe ? '${member.shortName} (você)' : member.shortName,
              style: context.text.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(text, style: AppTypography.money(size: 13, color: color)),
        ],
      ),
    );
  }
}

/// O vazio de um painel: uma linha de texto e o botão para resolver.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
      child: Row(
        children: [
          Expanded(child: Text(message, style: context.text.bodySmall)),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
