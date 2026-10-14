import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/bill_share.dart';
import '../../../data/models/member.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/inputs/date_range_dialog.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/media/attachment_tile.dart';

/// Registrar pagamento de uma pessoa em uma conta.
///
/// Permite selecionar várias parcelas de uma vez — que é como o
/// adiantamento acontece na vida real: um PIX só, cobrindo dois meses.
Future<void> showPaymentSheet(
  BuildContext context, {
  required Bill bill,
  required Member member,
  required List<BillShare> shares,
  BillShare? preselect,
}) =>
    showAppSheet(
      context: context,
      title: 'Pagamento de ${member.shortName}',
      subtitle: bill.title,
      builder: (_) => SharePaymentSheet(
        bill: bill,
        member: member,
        shares: shares,
        preselect: preselect,
      ),
    );

class SharePaymentSheet extends ConsumerStatefulWidget {
  const SharePaymentSheet({
    super.key,
    required this.bill,
    required this.member,
    required this.shares,
    this.preselect,
  });

  final Bill bill;
  final Member member;
  final List<BillShare> shares;
  final BillShare? preselect;

  @override
  ConsumerState<SharePaymentSheet> createState() => _SharePaymentSheetState();
}

class _SharePaymentSheetState extends ConsumerState<SharePaymentSheet> {
  late Set<String> _selected;
  List<Attachment> _receipts = [];
  DateTime _paidAt = DateTime.now();
  bool _saving = false;
  bool _uploading = false;
  double? _uploadProgress;

  List<BillShare> get _pending => widget.shares.where((s) => !s.isPaid).toList();
  List<BillShare> get _paid => widget.shares.where((s) => s.isPaid).toList();

  int get _selectedCents => widget.shares
      .where((s) => _selected.contains(s.id))
      .fold<int>(0, (sum, s) => sum + s.remainingCents);

  /// Parcelas selecionadas além da primeira em aberto = adiantamento.
  bool get _isAdvance {
    if (_selected.length < 2) {
      final first = _pending.firstOrNull;
      if (first == null || _selected.isEmpty) return false;
      return !_selected.contains(first.id);
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final pre = widget.preselect;
    _selected = pre != null && !pre.isPaid
        ? {pre.id}
        : {if (_pending.isNotEmpty) _pending.first.id};
  }

  Future<void> _pickReceipts() async {
    final files = await const FilePickerService().pickReceipts();
    if (files.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = null;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final tripId = ref.read(currentTripIdProvider);
      for (final file in files) {
        final attachment = await storage.upload(
          folder: StoragePaths.receipts(tripId, widget.bill.id),
          file: file,
          uploadedBy: ref.read(currentUidProvider),
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        setState(() => _receipts = [..._receipts, attachment]);
      }
    } catch (e) {
      if (mounted) AppToast.error('Falha no envio: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirm() async {
    final chosen = widget.shares.where((s) => _selected.contains(s.id)).toList();
    if (chosen.isEmpty) {
      AppToast.warning('Selecione ao menos uma parcela');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(billRepositoryProvider).payShares(
            ref.read(currentTripIdProvider),
            chosen,
            paidAt: _paidAt,
            receipts: _receipts,
          );
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(
          chosen.length == 1
              ? 'Pagamento registrado!'
              : '${chosen.length} parcelas quitadas!',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error('Não deu para registrar: $e');
      }
    }
  }

  Future<void> _undo(BillShare share) async {
    await ref.read(billRepositoryProvider).setSharePaid(
          ref.read(currentTripIdProvider),
          share,
          isPaid: false,
        );
    if (mounted) {
      Navigator.of(context).pop();
      AppToast.success('Pagamento desfeito');
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiverId = widget.shares.firstOrNull?.creditorId ?? widget.bill.paidByMemberId;
    final receiver = receiverId == null ? null : ref.watch(membersByIdProvider)[receiverId];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (receiver != null && receiver.id != widget.member.id)
                  _ReceiverBanner(receiver: receiver),

                if (_pending.isNotEmpty) ...[
                  Gap.vLg,
                  Row(
                    children: [
                      Expanded(
                        child: Text('Parcelas em aberto', style: context.text.labelLarge),
                      ),
                      if (_pending.length > 1)
                        TextButton(
                          onPressed: () => setState(() {
                            _selected = _selected.length == _pending.length
                                ? {}
                                : _pending.map((s) => s.id).toSet();
                          }),
                          child: Text(
                            _selected.length == _pending.length ? 'Limpar' : 'Quitar tudo',
                          ),
                        ),
                    ],
                  ),
                  Gap.vSm,
                  for (final share in _pending)
                    _ShareCheckTile(
                      share: share,
                      checked: _selected.contains(share.id),
                      onChanged: (v) => setState(() {
                        v ? _selected.add(share.id) : _selected.remove(share.id);
                      }),
                    ),
                ],

                if (_isAdvance && _selected.isNotEmpty) ...[
                  Gap.vMd,
                  _AdvanceBadge(count: _selected.length),
                ],

                Gap.vLg,
                InkWell(
                  borderRadius: Radii.brSm,
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context,
                      initialDate: _paidAt,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 2),
                      title: 'Data do pagamento',
                    );
                    if (picked != null) setState(() => _paidAt = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do pagamento',
                      prefixIcon: Icon(Icons.event_available_rounded, size: 20),
                    ),
                    child: Text(Fmt.dateWithYear(_paidAt), style: context.text.bodyMedium),
                  ),
                ),

                Gap.vXl,
                Text('Comprovante do PIX', style: context.text.labelLarge),
                Text('Foto do comprovante ou PDF', style: context.text.bodySmall),
                Gap.vMd,
                AttachmentStrip(
                  attachments: _receipts,
                  onAdd: _pickReceipts,
                  uploading: _uploading,
                  progress: _uploadProgress,
                  addLabel: 'PIX',
                  onDelete: (a) => setState(
                    () => _receipts = _receipts.where((r) => r.id != a.id).toList(),
                  ),
                ),

                if (_paid.isNotEmpty) ...[
                  Gap.vXl,
                  Divider(color: context.colors.outline),
                  Gap.vLg,
                  Text('Já pagas', style: context.text.labelLarge),
                  Gap.vSm,
                  for (final share in _paid)
                    _PaidShareTile(share: share, onUndo: () => _undo(share)),
                ],
              ],
            ),
          ),
        ),
        SheetActions(
          primaryLabel: _selectedCents > 0
              ? 'Confirmar ${Money.format(_selectedCents)}'
              : 'Confirmar',
          onPrimary: _confirm,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}

class _ReceiverBanner extends StatelessWidget {
  const _ReceiverBanner({required this.receiver});

  final Member receiver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border.all(color: context.colors.outline),
        borderRadius: Radii.brSm,
      ),
      child: Row(
        children: [
          MemberAvatar(member: receiver),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Transferir para ${receiver.shortName}',
                    style: context.text.titleSmall),
                Text(
                  receiver.pixKey ?? 'Chave PIX não cadastrada',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCheckTile extends StatelessWidget {
  const _ShareCheckTile({
    required this.share,
    required this.checked,
    required this.onChanged,
  });

  final BillShare share;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: InkWell(
        borderRadius: Radii.brSm,
        onTap: () => onChanged(!checked),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: Radii.brSm,
            border: Border.all(
              color: checked ? context.colors.onSurface : context.colors.outline,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: context.success,

              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      share.installmentNumber == null
                          ? 'Pagamento único'
                          : 'Parcela ${share.installmentNumber}',
                      style: context.text.titleSmall,
                    ),
                    if (share.dueDate != null)
                      Text(
                        share.isOverdue
                            ? 'venceu em ${Fmt.dateShort(share.dueDate!)}'
                            : 'vence em ${Fmt.dateShort(share.dueDate!)}',
                        style: context.text.bodySmall?.copyWith(
                          color: share.isOverdue ? AppColors.danger : null,
                          fontWeight: share.isOverdue ? FontWeight.w600 : null,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                Money.format(share.remainingCents),
                style: AppTypography.money(size: 14, color: context.colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaidShareTile extends StatelessWidget {
  const _PaidShareTile({required this.share, required this.onUndo});

  final BillShare share;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Icon(Icons.check, color: context.success, size: 18),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  share.installmentNumber == null
                      ? 'Pagamento único'
                      : 'Parcela ${share.installmentNumber}',
                  style: context.text.titleSmall,
                ),
                // A faixa útil aqui é de ~140px depois do ícone, do botão de
                // comprovante e do "Desfazer": os dois textos não cabem lado
                // a lado, então quebram em vez de estourar.
                Wrap(
                  spacing: Gap.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (share.paidAt != null)
                      Text('pago em ${Fmt.dateShort(share.paidAt!)}',
                          style: context.text.bodySmall),
                    if (share.isEarly)
                      Text(
                        'adiantado',
                        style: context.text.labelSmall?.copyWith(
                          color: context.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (share.receipts.isNotEmpty)
            IconButton(
              tooltip: 'Ver comprovante',
              onPressed: () => openAttachment(context, share.receipts.first),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
            ),
          TextButton(onPressed: onUndo, child: const Text('Desfazer')),
        ],
      ),
    );
  }
}

class _AdvanceBadge extends StatelessWidget {
  const _AdvanceBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border.all(color: context.colors.outline),
        borderRadius: Radii.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.fast_forward_outlined, color: context.colors.onSurfaceVariant, size: 16),
          Gap.hMd,
          Expanded(
            child: Text(
              'Adiantamento: $count parcelas em um pagamento só. '
              'O comprovante fica ligado a todas elas.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
