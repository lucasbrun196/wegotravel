import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/bill_entry.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/member.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/inputs/date_range_dialog.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/inputs/money_field.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/media/attachment_tile.dart';

Future<void> showEntryForm(
  BuildContext context, {
  required Bill bill,
  BillEntry? entry,
}) =>
    showAppSheet(
      context: context,
      title: entry == null ? 'Novo lançamento' : 'Editar lançamento',
      subtitle: bill.title,
      builder: (_) => EntryFormSheet(bill: bill, entry: entry),
    );

class EntryFormSheet extends ConsumerStatefulWidget {
  const EntryFormSheet({super.key, required this.bill, this.entry});

  final Bill bill;
  final BillEntry? entry;

  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  String? _paidByMemberId;
  List<Attachment> _receipts = [];
  bool _saving = false;
  bool _uploading = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = entry?.date ?? DateTime.now();
    _paidByMemberId = entry?.paidByMemberId ?? _defaultPayer();
    if (entry != null) {
      _descriptionController.text = entry.description;
      _notesController.text = entry.notes ?? '';
      _receipts = [...entry.receipts];
      MoneyField.setCents(_amountController, entry.amountCents);
    }
  }

  /// Quem está lançando costuma ser quem acabou de pagar. Se essa pessoa
  /// não divide a conta, fica quem bancou a conta.
  String? _defaultPayer() {
    final uid = ref.read(currentUidProvider);
    final bill = widget.bill;
    if (uid != null && (bill.participantIds.contains(uid) || bill.paidByMemberId == uid)) {
      return uid;
    }
    return bill.paidByMemberId ?? bill.participantIds.firstOrNull;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByMemberId == null) {
      AppToast.warning('Escolha quem pagou');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(billRepositoryProvider).saveEntry(
            ref.read(currentTripIdProvider),
            BillEntry(
              id: widget.entry?.id ?? '',
              billId: widget.bill.id,
              description: _descriptionController.text.trim(),
              amountCents: Money.parse(_amountController.text) ?? 0,
              date: _date,
              paidByMemberId: _paidByMemberId,
              receipts: _receipts,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              createdAt: widget.entry?.createdAt,
            ),
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success('Lançamento salvo!', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error('Não deu para salvar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MoneyField(
                    controller: _amountController,
                    label: 'Valor',
                    big: true,
                    autofocus: true,
                    validator: (_) =>
                        (Money.parse(_amountController.text) ?? 0) <= 0 ? 'Informe o valor' : null,
                  ),
                  Gap.vLg,
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      hintText: widget.bill.categories.contains(BillCategory.fuel)
                          ? 'Opcional · Posto Shell, BR-101'
                          : 'Opcional',
                    ),
                  ),
                  Gap.vXl,
                  Text('Quem pagou', style: context.text.labelLarge),
                  Text('Quem bancou este lançamento', style: context.text.bodySmall),
                  Gap.vSm,
                  _PayerSelector(
                    bill: widget.bill,
                    selected: _paidByMemberId,
                    onSelect: (id) => setState(() => _paidByMemberId = id),
                  ),
                  Gap.vLg,
                  InkWell(
                    borderRadius: Radii.brMd,
                    onTap: () async {
                      final picked = await showAppDatePicker(
                        context,
                        initialDate: _date,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 2),
                        title: 'Data do gasto',
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        prefixIcon: Icon(Icons.event_rounded, size: 20),
                      ),
                      child: Text(Fmt.dateWithYear(_date), style: context.text.bodyMedium),
                    ),
                  ),
                  Gap.vLg,
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      hintText: 'Opcional',
                    ),
                  ),
                  Gap.vXl,
                  Text('Comprovante', style: context.text.labelLarge),
                  Text('Foto da nota ou PDF', style: context.text.bodySmall),
                  Gap.vMd,
                  AttachmentStrip(
                    attachments: _receipts,
                    onAdd: _pickReceipts,
                    uploading: _uploading,
                    progress: _uploadProgress,
                    onDelete: (a) => setState(
                      () => _receipts = _receipts.where((r) => r.id != a.id).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}

/// Quem pagou o lançamento: quem divide a conta primeiro, e depois o
/// restante da viagem — às vezes paga quem nem entra na divisão.
class _PayerSelector extends ConsumerWidget {
  const _PayerSelector({required this.bill, required this.selected, required this.onSelect});

  final Bill bill;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final ordered = [
      ...members.where((m) => bill.participantIds.contains(m.id)),
      ...members.where((m) => !bill.participantIds.contains(m.id)),
    ];

    if (ordered.isEmpty) {
      return Text('Nenhum participante cadastrado', style: context.text.bodySmall);
    }

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final member in ordered)
          MemberChip(
            member: member,
            selected: member.id == selected,
            onTap: () => onSelect(member.id),
            trailing: member.id == selected
                ? Icon(Icons.radio_button_checked_rounded, size: 15, color: member.color)
                : null,
          ),
      ],
    );
  }
}
