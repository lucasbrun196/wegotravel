import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/bill_share.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/domain/category_badge.dart';
import '../controllers/money_controllers.dart';

/// Uma conta como linha da lista: nome, "Hospedagem, parcela 2/6, vence
/// 12/10" embaixo e o valor em mono à direita.
///
/// Vive dentro de um cartão único, separada das vizinhas por divisórias —
/// quem desenha o cartão e as divisórias é a lista.
class BillRow extends ConsumerWidget {
  const BillRow({super.key, required this.bill, this.onTap});

  final Bill bill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(sharesByBillProvider)[bill.id] ?? const <BillShare>[];
    final summary = BillSummary.from(bill, shares);
    final muted = context.colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: [
            CategoryBadge(icon: bill.category.icon, color: bill.category.color),
            Gap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _details(bill, shares),
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Gap.hMd,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.format(summary.totalCents),
                  style: AppTypography.money(size: 14, color: context.colors.onSurface),
                ),
                if (summary.isSettled)
                  Text(
                    'quitada',
                    style: context.text.labelSmall?.copyWith(color: context.success),
                  )
                else if (summary.shareCount > 0 && summary.paidCents > 0)
                  Text(
                    'falta ${Money.format(summary.pendingCents)}',
                    style: AppTypography.mono(size: 11, color: muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Hospedagem, parcela 2/6, vence 12/10"
  static String _details(Bill bill, List<BillShare> shares) {
    if (bill.isAccumulating && shares.isEmpty) {
      return [
        bill.categoriesLabel,
        bill.status == BillStatus.settled
            ? 'fechada'
            : '${bill.entriesCount} ${bill.entriesCount == 1 ? "lançamento" : "lançamentos"}',
      ].join(', ');
    }

    // A próxima cota que alguém ainda tem a pagar diz em que pé a conta está.
    final open = shares.where((s) => !s.isPaid && !s.isOwnerShare).toList()
      ..sort((a, b) {
        final ad = a.dueDate, bd = b.dueDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final next = open.isEmpty ? null : open.first;

    return [
      bill.category.label,
      if (bill.isInstallment)
        next?.installmentNumber != null
            ? 'parcela ${next!.installmentNumber}/${bill.installmentCount}'
            : '${bill.installmentCount}x',
      if (next?.dueDate != null) 'vence ${Fmt.dateShort(next!.dueDate!)}',
    ].join(', ');
  }
}
