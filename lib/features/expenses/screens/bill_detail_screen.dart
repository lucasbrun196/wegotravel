import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/destinations.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/bill_entry.dart';
import '../../../data/models/bill_settlement.dart';
import '../../../data/models/bill_share.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/member.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/feedback/animated_progress_bar.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../../shared/widgets/media/attachment_tile.dart';
import '../controllers/money_controllers.dart';
import '../widgets/bill_form_sheet.dart';
import '../widgets/entry_form_sheet.dart';
import '../widgets/settlement_section.dart';
import '../widgets/share_payment_sheet.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billProvider(billId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: billAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: ShimmerList(itemCount: 4, itemHeight: 100),
        ),
        error: (e, _) => ErrorView(message: 'Não deu para carregar a conta', details: '$e'),
        data: (bill) => bill == null
            ? EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Conta não encontrada',
                message: 'Ela pode ter sido apagada por outra pessoa.',
                actionLabel: 'Voltar',
                onAction: () => context.pop(),
              )
            : _BillDetailBody(bill: bill),
      ),
    );
  }
}

class _BillDetailBody extends ConsumerWidget {
  const _BillDetailBody({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billSummaryProvider(bill));
    final sharesAsync = ref.watch(billSharesProvider(bill.id));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: ContentContainer(
              child: Padding(
                padding: EdgeInsets.only(top: context.isMobile ? Gap.md : Gap.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(bill: bill),
                    Gap.vLg,
                    _BillHeader(bill: bill, summary: summary),
                    Gap.vXl,
                    if (bill.isAccumulating)
                      _EntriesSection(bill: bill)
                    else
                      _SharesSection(bill: bill, shares: sharesAsync.valueOrNull ?? const []),
                    if (bill.isAccumulating && bill.status == BillStatus.settled) ...[
                      Gap.vXl,
                      SettlementSection(bill: bill),
                    ],
                    if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                      Gap.vXl,
                      const SectionHeader(title: 'Observações'),
                      GlassCard(child: Text(bill.notes!, style: context.text.bodyMedium)),
                    ],
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go(
            Routes.tripSection(ref.read(currentTripIdProvider), AppDestination.expenses),
          ),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
        ),
        const Spacer(),
        IconButton(
          onPressed: () => showBillForm(context, bill: bill),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Editar conta',
        ),
        IconButton(
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Excluir conta',
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta conta?'),
        content: Text(
          'Todos os lançamentos, cotas e comprovantes de "${bill.title}" '
          'serão apagados. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    final tripId = ref.read(currentTripIdProvider);

    // Sai da tela antes de apagar. A exclusão varre subcoleções e
    // arquivos, e o documento some do stream no meio do caminho — ficar
    // aqui faria a tela piscar "conta não encontrada" antes de sair.
    context.go(Routes.tripSection(tripId, AppDestination.expenses));

    try {
      await ref.read(billRepositoryProvider).deleteBill(tripId, bill.id);
      AppToast.success('Conta excluída');
    } catch (e) {
      AppToast.error('Não deu para excluir a conta: $e');
    }
  }
}

class _BillHeader extends ConsumerWidget {
  const _BillHeader({required this.bill, required this.summary});

  final Bill bill;
  final BillSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersById = ref.watch(membersByIdProvider);
    // Em conta aberta cada lançamento tem o seu pagador: o rótulo diz quem
    // bancou de fato, e não só quem foi marcado no cadastro.
    final payerIds = bill.isAccumulating
        ? {
            for (final e in ref.watch(billEntriesProvider(bill.id)).valueOrNull ?? const [])
              ?e.paidByMemberId ?? bill.paidByMemberId,
          }
        : {?bill.paidByMemberId};
    final payerLabel = payerIds.length > 1
        ? '${payerIds.length} pessoas bancaram'
        : payerIds.isEmpty || membersById[payerIds.first] == null
            ? null
            : '${membersById[payerIds.first]!.shortName} bancou';
    final muted = context.colors.onSurfaceVariant;

    return GlassCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [bill.categoriesLabel, ?payerLabel].join(' · '),
            style: context.text.labelSmall,
          ),
          Gap.vXs,
          Text(
            bill.title,
            style: context.isMobile ? context.text.headlineMedium : context.text.displaySmall,
          ),
          Gap.vLg,
          Text(
            Money.format(summary.totalCents),
            style: AppTypography.money(
              size: context.isMobile ? 28 : 32,
              color: context.colors.onSurface,
            ),
          ),
          if (bill.isInstallment)
            Text(
              '${bill.installmentCount}x de ${Money.format(bill.effectiveInstallmentCents)} '
              '· ${Money.format(bill.perPersonPerInstallmentCents)} por pessoa',
              style: AppTypography.mono(size: 12, color: muted),
            ),
          if (summary.shareCount > 0) ...[
            Gap.vLg,
            AnimatedProgressBar(value: summary.progress, height: 8),
            Gap.vSm,
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.isSettled
                        ? 'Quitada'
                        : '${Money.format(summary.pendingCents)} em aberto',
                    style: AppTypography.mono(
                      size: 12,
                      color: summary.isSettled ? context.success : muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  Fmt.percent(summary.progress),
                  style: AppTypography.mono(size: 12, color: muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Cotas: uma linha por pessoa, com as parcelas em quadradinhos
// ---------------------------------------------------------------

class _SharesSection extends ConsumerWidget {
  const _SharesSection({required this.bill, required this.shares});

  final Bill bill;
  final List<BillShare> shares;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shares.isEmpty) {
      return const SizedBox.shrink();
    }

    final membersById = ref.watch(membersByIdProvider);
    final byMember = <String, List<BillShare>>{};
    for (final share in shares) {
      byMember.putIfAbsent(share.memberId, () => []).add(share);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Divisão',
          subtitle: bill.isInstallment
              ? 'Toque em uma pessoa ou parcela para registrar o pagamento'
              : 'Toque em uma pessoa para registrar o pagamento',
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, entry) in byMember.entries.indexed) ...[
                if (i > 0) const Divider(),
                _MemberShareRow(
                  bill: bill,
                  member: membersById[entry.key],
                  memberId: entry.key,
                  shares: entry.value,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberShareRow extends ConsumerWidget {
  const _MemberShareRow({
    required this.bill,
    required this.member,
    required this.memberId,
    required this.shares,
  });

  final Bill bill;
  final Member? member;
  final String memberId;
  final List<BillShare> shares;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = shares.first.isOwnerShare;
    final total = shares.fold<int>(0, (sum, s) => sum + s.amountCents);
    final paid = shares.where((s) => s.isPaid || s.isOwnerShare).length;
    final pendingCents = isOwner
        ? 0
        : shares.where((s) => !s.isPaid).fold<int>(0, (sum, s) => sum + s.remainingCents);
    final isMe = ref.watch(currentUidProvider) == memberId;
    final settled = isOwner || pendingCents == 0;
    final name = member?.shortName ?? memberId;

    return InkWell(
      onTap: isOwner || member == null
          ? null
          : () => showPaymentSheet(context, bill: bill, member: member!, shares: shares),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (member != null) ...[MemberAvatar(member: member!), Gap.hMd],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Com `ellipsis`: o fallback aqui é o uid, com 28
                      // caracteres, e ele estourava a linha.
                      Text(
                        isMe ? '$name (você)' : name,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isOwner
                            ? 'bancou a conta · a própria parte já está inclusa'
                            : pendingCents == 0
                                ? 'tudo pago'
                                : 'falta ${Money.format(pendingCents)}',
                        style: context.text.bodySmall?.copyWith(
                          color: settled ? context.success : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.hSm,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.format(total),
                      style: AppTypography.money(size: 14, color: context.colors.onSurface),
                    ),
                    if (bill.isInstallment)
                      Text(
                        '$paid/${shares.length} parcelas',
                        style: AppTypography.mono(
                          size: 11,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (bill.isInstallment) ...[
              Gap.vMd,
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final share in shares)
                    _InstallmentBox(
                      share: share,
                      onTap: isOwner || member == null
                          ? null
                          : () => showPaymentSheet(
                                context,
                                bill: bill,
                                member: member!,
                                shares: shares,
                                preselect: share,
                              ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uma parcela: verde cheia paga, contorno vermelho vencida, contorno
/// cinza pendente.
class _InstallmentBox extends StatelessWidget {
  const _InstallmentBox({required this.share, this.onTap});

  final BillShare share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.success;
    final (Color? bg, Color border, Color fg, bool check) = share.isOwnerShare
        ? (context.successSoft, context.successSoft, accent, true)
        : share.isPaid
            ? (accent, accent, context.colors.onPrimary, true)
            : share.isOverdue
                ? (null, AppColors.danger, AppColors.danger, false)
                : (null, context.colors.outline, context.colors.onSurfaceVariant, false);

    return Tooltip(
      message: [
        'Parcela ${share.installmentNumber}',
        Money.format(share.amountCents),
        if (share.dueDate != null) 'vence ${Fmt.dateShort(share.dueDate!)}',
        if (share.isPaid && share.paidAt != null) 'pago ${Fmt.dateShort(share.paidAt!)}',
      ].join(' · '),
      child: InkWell(
        borderRadius: Radii.brSm,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 36,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.brSm,
            border: Border.all(color: border),
          ),
          child: Center(
            child: check
                ? Icon(Icons.check, size: 16, color: fg)
                : Text(
                    '${share.installmentNumber}',
                    style: AppTypography.mono(size: 12, color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Lançamentos da conta aberta
// ---------------------------------------------------------------

class _EntriesSection extends ConsumerWidget {
  const _EntriesSection({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(billEntriesProvider(bill.id));
    final isSettled = bill.status == BillStatus.settled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Lançamentos',
          subtitle: isSettled ? 'Conta fechada. Reabra para lançar mais.' : null,
          trailing: isSettled
              ? null
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => showEntryForm(context, bill: bill),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Lançar'),
                ),
        ),
        entriesAsync.when(
          loading: () => const ShimmerList(itemCount: 2, itemHeight: 56),
          error: (e, _) => ErrorView(message: 'Erro ao carregar', details: '$e'),
          data: (entries) => entries.isEmpty
              ? GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nenhum lançamento ainda', style: context.text.titleSmall),
                      Gap.vXs,
                      Text(
                        'Lance cada gasto aqui. No fechamento o app divide o total.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                )
              : GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, entry) in entries.indexed) ...[
                        if (i > 0) const Divider(),
                        _EntryTile(bill: bill, entry: entry),
                      ],
                    ],
                  ),
                ),
        ),
        Gap.vLg,
        _AccumulatingFooter(bill: bill, entries: entriesAsync.valueOrNull ?? const []),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.bill, required this.entry});

  final Bill bill;
  final BillEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersByIdProvider);
    final payer = members[entry.paidByMemberId ?? bill.paidByMemberId];

    return InkWell(
      onTap: bill.status == BillStatus.settled
          ? null
          : () => showEntryForm(context, bill: bill, entry: entry),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
        child: _EntryTileBody(
          bill: bill,
          entry: entry,
          payer: payer,
          split: entry.isSplitByAll ? null : _splitLabel(entry.splitAmong(bill), members),
          ref: ref,
        ),
      ),
    );
  }

  /// "Só Lucas", "Lucas e Ana", "Lucas, Ana e Pedro", "5 pessoas".
  static String _splitLabel(List<String> ids, Map<String, Member> members) {
    final names = [for (final id in ids) members[id]?.shortName ?? 'alguém'];
    return switch (names.length) {
      1 => 'Só ${names.single}',
      2 || 3 => '${names.take(names.length - 1).join(', ')} e ${names.last}',
      _ => '${names.length} pessoas',
    };
  }
}

/// O corpo do lançamento.
///
/// No celular, descrição + comprovante + valor + excluir na mesma linha
/// deixavam pouco espaço para a descrição, que quebrava em várias linhas.
/// Em tela estreita as ações descem para uma segunda linha.
class _EntryTileBody extends StatelessWidget {
  const _EntryTileBody({
    required this.bill,
    required this.entry,
    required this.payer,
    required this.split,
    required this.ref,
  });

  final Bill bill;
  final BillEntry entry;
  final Member? payer;

  /// Quem divide, quando não são todos da conta.
  final String? split;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final receipt = entry.receipts.isEmpty
        ? null
        : IconButton(
            tooltip: 'Comprovante',
            onPressed: () => openAttachment(context, entry.receipts.first),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
          );

    final delete = bill.status == BillStatus.settled
        ? null
        : IconButton(
            tooltip: 'Excluir lançamento',
            onPressed: () => ref
                .read(billRepositoryProvider)
                .deleteEntry(ref.read(currentTripIdProvider), entry),
            icon: const Icon(Icons.close, size: 16),
          );

    final amount = Text(
      Money.format(entry.amountCents),
      style: AppTypography.money(size: 14, color: context.colors.onSurface),
    );

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          // A descrição é opcional: sem ela, o lançamento leva o nome da
          // categoria, que na gasolina já diz tudo.
          entry.description.isEmpty ? bill.category.label : entry.description,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          [
            if (payer != null) '${payer!.shortName} pagou',
            Fmt.dateShortWithYear(entry.date),
          ].join(' · '),
          style: context.text.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Só aparece quando foge da regra: dividido por todos é o normal.
        if (split != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.call_split_rounded, size: 13, color: context.colors.primary),
                Gap.hXs,
                Flexible(
                  child: Text(
                    'Dividido: ${split!}',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (!context.isNarrow) {
      return Row(
        children: [
          Expanded(child: label),
          ?receipt,
          Gap.hSm,
          amount,
          if (delete != null) delete else Gap.hSm,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: label),
            Gap.hSm,
            amount,
            Gap.hSm,
          ],
        ),
        if (receipt != null || delete != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [?receipt, ?delete],
          ),
      ],
    );
  }
}

/// Quanto fica para uma pessoa, numa pílula com o avatar dela. O valor
/// troca com um esmaecer quando um lançamento muda.
class _OwedPill extends StatelessWidget {
  const _OwedPill({required this.member, required this.cents});

  final Member member;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, Gap.md, 3),
      decoration: BoxDecoration(
        color: member.color.withValues(alpha: context.isDark ? 0.18 : 0.08),
        borderRadius: Radii.brPill,
        border: Border.all(color: member.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberAvatar(member: member, size: 22),
          Gap.hSm,
          Text(member.shortName, style: context.text.labelLarge),
          Gap.hSm,
          AnimatedSwitcher(
            duration: Motion.normal,
            child: Text(
              Money.format(cents),
              key: ValueKey(cents),
              style: AppTypography.money(size: 13, color: context.colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Total acumulado + ação de fechar/reabrir a conta.
class _AccumulatingFooter extends ConsumerWidget {
  const _AccumulatingFooter({required this.bill, required this.entries});

  final Bill bill;
  final List<BillEntry> entries;

  /// Algum lançamento é só de algumas pessoas: aí cada um fica com um
  /// valor diferente, e "X para cada" deixa de ser verdade.
  bool get _hasPartialSplit => entries.any((e) => !e.isSplitByAll);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSettled = bill.status == BillStatus.settled;
    final perPerson = bill.participantIds.isEmpty
        ? 0
        : Money.divide(bill.entriesTotalCents, bill.participantIds.length).first;
    final members = ref.watch(membersByIdProvider);
    final settlement = _hasPartialSplit ? BillSettlement.of(bill, entries) : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Total acumulado', style: context.text.titleMedium)),
              Text(
                Money.format(bill.entriesTotalCents),
                style: AppTypography.money(size: 22, color: context.colors.onSurface),
              ),
            ],
          ),
          if (settlement != null) ...[
            Gap.vXs,
            Text('Cada lançamento entra só na parte de quem o divide:', style: context.text.bodySmall),
            Gap.vSm,
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final id in settlement.memberIds)
                  if (members[id] case final member? when settlement.owedBy(id) > 0)
                    _OwedPill(member: member, cents: settlement.owedBy(id)),
              ],
            ),
          ] else if (bill.participantIds.isNotEmpty) ...[
            Gap.vXs,
            Text(
              'Daria ${Money.format(perPerson)} para cada uma das '
              '${bill.participantIds.length} pessoas',
              style: context.text.bodySmall,
            ),
          ],
          Gap.vLg,
          if (isSettled)
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(billRepositoryProvider)
                  .reopenBill(ref.read(currentTripIdProvider), bill.id),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Reabrir para lançar mais'),
            )
          else
            FilledButton.icon(
              onPressed: bill.entriesTotalCents <= 0
                  ? null
                  : () => _close(context, ref),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Fechar e dividir'),
            ),
        ],
      ),
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fechar a conta?'),
        content: Text(
          '${_hasPartialSplit ? 'Cada lançamento do total de ${Money.format(bill.entriesTotalCents)} '
              'será dividido entre quem o divide' : 'O total de ${Money.format(bill.entriesTotalCents)} '
              'será dividido entre ${bill.participantIds.length} pessoas'}. '
          'O app soma quanto cada um pagou e calcula quem transfere quanto para quem. '
          'Você pode reabrir depois se precisar lançar mais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fechar e dividir'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    await ref
        .read(billRepositoryProvider)
        .closeAccumulatingBill(ref.read(currentTripIdProvider), bill);
    if (context.mounted) {
      AppToast.success('Conta fechada e dividida');
    }
  }
}
