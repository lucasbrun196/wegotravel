import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/category_badge.dart';
import '../../../shared/widgets/feedback/animated_progress_bar.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/add_button.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/layout/stat_strip.dart';
import '../controllers/itinerary_controllers.dart';
import '../widgets/itinerary_form_sheet.dart';
import '../widgets/itinerary_row.dart';

class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraryAsync = ref.watch(itineraryProvider);
    final days = ref.watch(itineraryDaysProvider);
    final summary = ref.watch(itinerarySummaryProvider);

    return AppPage(
      title: 'Roteiro',
      action: AddButton(label: 'Nova atividade', onPressed: () => showItineraryForm(context)),
      children: [
        if (summary.total > 0) ...[
          StatStrip(
            cells: [
              StatCell(label: 'Atividades', value: '${summary.total}', color: AppColors.turquoise),
              StatCell(
                label: 'Feitas',
                color: AppColors.success,
                value: '${summary.done}/${summary.total}',
                footnote: Fmt.percent(summary.progress),
              ),
              StatCell(label: 'Dias', value: '${summary.days}', color: AppColors.grape),
              StatCell.money(
                label: 'Contas ligadas',
                color: AppColors.sunset,
                cents: summary.linkedCents,
                footnote: '${summary.linkedCount} '
                    '${summary.linkedCount == 1 ? "atividade" : "atividades"}',
              ),
            ],
          ),
          const _SpendByCategory(),
          Gap.vXl,
        ],

        itineraryAsync.when(
          loading: () => const ShimmerList(itemCount: 3, itemHeight: 64),
          error: (e, _) => ErrorView(
            message: 'Não deu para carregar o roteiro',
            details: '$e',
            onRetry: () => ref.invalidate(itineraryProvider),
          ),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: Gap.xl),
                  child: EmptyState(
                    icon: Icons.view_agenda_outlined,
                    title: 'Roteiro vazio',
                    message: 'Adicione um passeio, restaurante ou trilha e ligue à conta dele.',
                    actionLabel: 'Nova atividade',
                    onAction: () => showItineraryForm(context),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A chave segura o recolhido no dia certo quando um
                    // dia entra ou sai da lista.
                    for (final day in days) _DaySection(key: ValueKey(day.dayKey), day: day),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Onde o dinheiro do roteiro está indo, por tipo de atividade.
class _SpendByCategory extends ConsumerWidget {
  const _SpendByCategory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = ref.watch(itinerarySpendByCategoryProvider);
    if (byCategory.isEmpty) return const SizedBox.shrink();

    final total = byCategory.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Gasto por categoria'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, entry) in byCategory.entries.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            entry.key.label,
                            style: context.text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: AnimatedProgressBar(
                            value: total == 0 ? 0 : entry.value / total,
                          ),
                        ),
                        Gap.hLg,
                        Text(
                          Money.format(entry.value),
                          style: AppTypography.money(size: 13, color: context.colors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Um dia do roteiro: cabeçalho e as atividades em linhas de tabela.
///
/// O cabeçalho recolhe e reabre o dia: o cartão encolhe até sumir enquanto
/// esmaece, e a seta gira. Recolhido, o cabeçalho mostra os ícones das
/// categorias do dia, para ele não virar só uma data. Todo dia começa
/// aberto; o estado vive só enquanto a tela está montada.
class _DaySection extends StatefulWidget {
  const _DaySection({super.key, required this.day});

  final ItineraryDay day;

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Motion.slow, value: 1);

  // Sem o `Motion.spring`: passar do ponto aqui esticaria o cartão além da
  // altura dele. O conteúdo só aparece depois que o espaço começou a abrir,
  // e some antes de o espaço fechar.
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: Motion.enter,
    reverseCurve: Motion.exit,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
  );

  bool get _open => _controller.status.isForwardOrCompleted;

  void _toggle() => _setOpen(!_open);

  void _setOpen(bool open) {
    if (context.reduceMotion) {
      _controller.value = open ? 1 : 0;
    } else if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeader(
            day: day,
            open: _open,
            onToggle: _toggle,
            onAdd: () {
              // Quem adiciona num dia recolhido quer ver a atividade nova.
              _setOpen(true);
              showItineraryForm(context, suggestedDate: day.date);
            },
          ),
          SizeTransition(
            sizeFactor: _size,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.md),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ItineraryTableHeader(),
                      for (var i = 0; i < day.items.length; i++) ...[
                        if (i > 0) const Divider(),
                        FadeSlideIn(index: i, child: ItineraryRow(item: day.items[i])),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.open,
    required this.onToggle,
    required this.onAdd,
  });

  final ItineraryDay day;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final count = day.items.length;
    final muted = context.colors.onSurfaceVariant;
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    final categories = {for (final i in day.items) i.category};

    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: open ? 'Recolher o dia' : 'Mostrar o dia',
            waitDuration: const Duration(milliseconds: 600),
            child: InkWell(
              onTap: onToggle,
              borderRadius: Radii.brSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Row(
                  children: [
                    // Aberto a seta aponta para baixo; recolhido, para o lado.
                    AnimatedRotation(
                      turns: open ? 0 : -0.25,
                      duration: duration,
                      curve: Motion.spring,
                      child: Icon(Icons.expand_more_rounded, size: 20, color: muted),
                    ),
                    Gap.hXs,
                    Text(
                      '${Fmt.weekdayShort(day.date)} ${Fmt.dateShort(day.date)}'.toUpperCase(),
                      style: AppTypography.mono(
                        size: 13,
                        weight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    if (day.isToday) ...[
                      Gap.hSm,
                      Text(
                        'hoje',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Gap.hMd,
                    Flexible(
                      child: Text(
                        '$count ${count == 1 ? "atividade" : "atividades"}'
                        '${day.doneCount > 0 ? " · ${day.doneCount} feitas" : ""}',
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Recolhido, o dia ainda diz o que tem: os ícones das
                    // categorias entram deslizando enquanto o cartão sai.
                    AnimatedSize(
                      duration: duration,
                      curve: Motion.enter,
                      child: AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(-0.15, 0), end: Offset.zero)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: open
                            ? const SizedBox.shrink()
                            : Padding(
                                key: const ValueKey('icons'),
                                padding: const EdgeInsets.only(left: Gap.md),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final c in categories.take(6))
                                      Padding(
                                        padding: const EdgeInsets.only(right: 3),
                                        child: CategoryBadge(
                                          icon: c.icon,
                                          color: c.color,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Adicionar neste dia',
          visualDensity: VisualDensity.compact,
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}
