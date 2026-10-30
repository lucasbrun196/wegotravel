import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/bill_share.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/cards/tinted_panel.dart';
import '../../../shared/widgets/feedback/animated_counter.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/add_button.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/stat_strip.dart';
import '../controllers/money_controllers.dart';
import '../widgets/bill_card.dart';
import '../widgets/bill_form_sheet.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(moneyOverviewProvider);
    final currentMember = ref.watch(currentMemberProvider);

    return AppPage(
      title: 'Contas',
      action: AddButton(label: 'Nova conta', onPressed: () => showBillForm(context)),
      children: [
        if (currentMember != null) ...[
          const _YouOweCard(),
          Gap.vMd,
        ],
        StatStrip(
          minCellWidth: 100,
          valueSize: 16,
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
          ],
        ),
        Gap.vXl,
        const _BillList(),
      ],
    );
  }
}

/// O número que importa para quem abriu a tela. Coral enquanto há o que
/// pagar; quando zera, o painel passa devagar para o verde do mar.
class _YouOweCard extends ConsumerWidget {
  const _YouOweCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(myPendingSharesProvider);
    final owedToMe = ref.watch(owedToMeProvider);
    final iOwe = pending.fold<int>(0, (sum, s) => sum + s.remainingCents);
    final bills = {
      for (final b in ref.watch(billsProvider).valueOrNull ?? const <Bill>[]) b.id: b,
    };
    final next = pending.isEmpty ? null : pending.first;
    final tone = iOwe > 0 ? context.debt : context.success;

    final nextLine = next == null
        ? 'Nada pendente'
        : [
            'Próxima: ${bills[next.billId]?.title ?? "conta"}',
            if (next.installmentNumber != null &&
                (bills[next.billId]?.isInstallment ?? false))
              'parcela ${next.installmentNumber}/${bills[next.billId]!.installmentCount}',
            if (next.dueDate != null) 'vence ${Fmt.dateShort(next.dueDate!)}',
            Money.format(next.remainingCents),
          ].join(', ');

    final owe = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Você deve',
          style: context.text.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w600),
        ),
        Gap.vXs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedMoney(
            iOwe / 100,
            style: AppTypography.money(size: 36, weight: FontWeight.w700, color: tone),
          ),
        ),
        Gap.vXs,
        Text(
          nextLine,
          style: context.text.bodySmall?.copyWith(
            color: next?.isOverdue ?? false ? AppColors.danger : context.colors.onSurface,
            fontWeight: next?.isOverdue ?? false ? FontWeight.w600 : null,
          ),
        ),
      ],
    );

    final receive = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A receber',
          style: context.text.labelLarge?.copyWith(
            color: context.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        Gap.vXs,
        Text(
          Money.format(owedToMe),
          style: AppTypography.money(size: 22, color: context.success),
        ),
      ],
    );

    return TintedPanel(
      color: iOwe > 0 ? context.debtSoft : context.successSoft,
      child: owedToMe <= 0
          ? owe
          : context.isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [owe, Gap.vLg, receive],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: owe), Gap.hXl, receive],
                ),
    );
  }
}

enum _Filter {
  open('Em aberto'),
  settled('Quitadas'),
  all('Todas');

  const _Filter(this.label);
  final String label;
}

/// Os filtros e a lista de contas num cartão só.
class _BillList extends ConsumerStatefulWidget {
  const _BillList();

  @override
  ConsumerState<_BillList> createState() => _BillListState();
}

class _BillListState extends ConsumerState<_BillList> {
  _Filter _filter = _Filter.open;

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsProvider);
    final byBill = ref.watch(sharesByBillProvider);

    bool settled(Bill b) => BillSummary.from(b, byBill[b.id] ?? const <BillShare>[]).isSettled;

    return billsAsync.when(
      loading: () => const ShimmerList(itemCount: 3, itemHeight: 56),
      error: (e, _) => ErrorView(message: 'Não deu para carregar as contas', details: '$e'),
      data: (bills) {
        if (bills.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.lg),
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma conta ainda',
              message: 'Cadastre o aluguel, a gasolina e os passeios. O app divide entre todos.',
              actionLabel: 'Nova conta',
              onAction: () => showBillForm(context),
            ),
          );
        }

        final counts = {
          _Filter.open: bills.where((b) => !settled(b)).length,
          _Filter.settled: bills.where(settled).length,
          _Filter.all: bills.length,
        };
        final shown = switch (_filter) {
          _Filter.open => bills.where((b) => !settled(b)).toList(),
          _Filter.settled => bills.where(settled).toList(),
          _Filter.all => bills,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final f in _Filter.values)
                  ChoiceChip(
                    label: Text('${f.label} ${counts[f]}'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            Gap.vMd,
            if (shown.isEmpty)
              GlassCard(
                child: Text(
                  _filter == _Filter.open ? 'Nenhuma conta em aberto.' : 'Nenhuma conta quitada.',
                  style: context.text.bodySmall,
                ),
              )
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, bill) in shown.indexed) ...[
                      if (i > 0) const Divider(),
                      FadeSlideIn(
                        index: i,
                        child: BillRow(
                          bill: bill,
                          onTap: () => context.go(
                            '/viagem/${ref.read(currentTripIdProvider)}/gastos/${bill.id}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
