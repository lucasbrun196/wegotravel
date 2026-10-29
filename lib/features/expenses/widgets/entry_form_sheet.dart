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

  /// Quem divide este lançamento. Começa com todos da conta.
  late Set<String> _splitters;
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
    _splitters = {
      ...(entry == null || entry.isSplitByAll ? widget.bill.participantIds : entry.participantIds),
    };
    // A prévia do "quanto fica para cada um" acompanha o valor digitado.
    _amountController.addListener(_onAmountChanged);
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

  void _onAmountChanged() => setState(() {});

  /// Todos da conta marcados viram a lista vazia, que quer dizer "todos" —
  /// e assim continua valendo se alguém entrar na conta depois.
  List<String> get _participantIdsToSave {
    final all = widget.bill.participantIds;
    if (all.every(_splitters.contains)) return const [];
    return [
      ...all.where(_splitters.contains),
      ..._splitters.where((id) => !all.contains(id)),
    ];
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
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
    if (widget.bill.participantIds.isNotEmpty && _splitters.isEmpty) {
      AppToast.warning('Escolha quem divide este lançamento');
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
              participantIds: _participantIdsToSave,
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
                  if (widget.bill.participantIds.isNotEmpty) ...[
                    Gap.vXl,
                    Text('Quem divide', style: context.text.labelLarge),
                    Text('Quem entra no racha deste lançamento', style: context.text.bodySmall),
                    Gap.vSm,
                    _SplitSelector(
                      bill: widget.bill,
                      selected: _splitters,
                      amountCents: Money.parse(_amountController.text) ?? 0,
                      onChanged: (ids) => setState(() => _splitters = ids),
                    ),
                  ],
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
          // O `MemberChip` já marca o escolhido com um check animado; um
          // rádio ao lado dele repetia a mesma informação.
          MemberChip(
            member: member,
            selected: member.id == selected,
            onTap: () => onSelect(member.id),
          ),
      ],
    );
  }
}

/// Quem divide o lançamento: as pessoas da conta, marcáveis uma a uma, e
/// dois atalhos — "Todos" e "Só eu". Cada pessoa marcada mostra embaixo do
/// nome quanto fica para ela, e uma linha resume a divisão; os dois mudam
/// com animação enquanto o valor é digitado.
class _SplitSelector extends ConsumerWidget {
  const _SplitSelector({
    required this.bill,
    required this.selected,
    required this.amountCents,
    required this.onChanged,
  });

  final Bill bill;
  final Set<String> selected;
  final int amountCents;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersByIdProvider);
    final uid = ref.watch(currentUidProvider);
    final all = bill.participantIds;
    // Quem já tinha saído da conta mas está no lançamento continua visível.
    final ids = [...all, ...selected.where((id) => !all.contains(id))];

    final among = ids.where(selected.contains).toList();
    final custom = bill.splitMode == SplitMode.custom && bill.customWeights.isNotEmpty;
    final parts = among.isEmpty
        ? const <int>[]
        : custom
            ? Money.divideByWeights(amountCents, among.map((m) => bill.customWeights[m] ?? 1).toList())
            : Money.divide(amountCents, among.length);
    final partOf = {for (var i = 0; i < among.length; i++) among[i]: parts[i]};

    final isAll = all.every(selected.contains) && selected.length == all.length;
    final isOnlyMe = uid != null && selected.length == 1 && selected.contains(uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Gap.sm,
          children: [
            _QuickPick(
              label: 'Todos',
              icon: Icons.groups_rounded,
              active: isAll,
              onTap: () => onChanged({...all}),
            ),
            if (uid != null && all.contains(uid))
              _QuickPick(
                label: 'Só eu',
                icon: Icons.person_rounded,
                active: isOnlyMe,
                onTap: () => onChanged({uid}),
              ),
          ],
        ),
        Gap.vMd,
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final id in ids)
              if (members[id] case final member?)
                MemberChip(
                  member: member,
                  selected: selected.contains(id),
                  subtitle: selected.contains(id)
                      ? (amountCents > 0 ? Money.format(partOf[id] ?? 0) : 'divide')
                      : 'fora',
                  onTap: () => onChanged(
                    selected.contains(id)
                        ? ({...selected}..remove(id))
                        : {...selected, id},
                  ),
                ),
          ],
        ),
        Gap.vSm,
        AnimatedSwitcher(
          duration: Motion.normal,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
          child: _summary(context, among, parts, members, isAll, custom),
        ),
      ],
    );
  }

  Widget _summary(
    BuildContext context,
    List<String> among,
    List<int> parts,
    Map<String, Member> members,
    bool isAll,
    bool custom,
  ) {
    final (IconData icon, String text, Color color) = switch (among.length) {
      0 => (
          Icons.error_outline_rounded,
          'Escolha pelo menos uma pessoa',
          context.colors.error,
        ),
      1 => (
          Icons.person_rounded,
          'Fica todo com ${members[among.single]?.shortName ?? "uma pessoa"}',
          context.colors.onSurfaceVariant,
        ),
      _ when custom => (
          Icons.tune_rounded,
          'Dividido entre ${among.length} pelos pesos da conta',
          context.colors.onSurfaceVariant,
        ),
      _ when amountCents <= 0 => (
          Icons.call_split_rounded,
          isAll ? 'Dividido entre todos os ${among.length}' : 'Dividido entre ${among.length} pessoas',
          context.colors.onSurfaceVariant,
        ),
      _ => (
          Icons.call_split_rounded,
          // O centavo de resto vai para alguém: "cerca de" avisa que um
          // pode pagar um centavo a mais.
          '${parts.toSet().length > 1 ? "Cerca de " : ""}${Money.format(parts.last)} '
              'para cada um ${isAll ? "dos ${among.length}" : "de ${among.length}"}',
          context.colors.onSurfaceVariant,
        ),
    };

    return Row(
      key: ValueKey(text),
      children: [
        Icon(icon, size: 16, color: color),
        Gap.hXs,
        Flexible(child: Text(text, style: context.text.bodySmall?.copyWith(color: color))),
      ],
    );
  }
}

/// Atalho de seleção, aceso quando a escolha atual é exatamente a dele.
class _QuickPick extends StatelessWidget {
  const _QuickPick({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final fg = active ? primary : context.colors.onSurfaceVariant;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: Radii.brPill,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
          decoration: BoxDecoration(
            color: active ? primary.withValues(alpha: context.isDark ? 0.2 : 0.1) : null,
            borderRadius: Radii.brPill,
            border: Border.all(color: active ? primary : context.colors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              Gap.hXs,
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
