import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/member.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/inputs/date_range_dialog.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/inputs/money_field.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/inputs/multi_choice_chips.dart';

Future<void> showBillForm(BuildContext context, {Bill? bill}) => showAppSheet(
      context: context,
      title: bill == null ? 'Nova conta' : 'Editar conta',
      subtitle: bill == null
          ? 'Um gasto da viagem, dividido entre os participantes'
          : bill.title,
      builder: (_) => BillFormSheet(bill: bill),
    );

class BillFormSheet extends ConsumerStatefulWidget {
  const BillFormSheet({super.key, this.bill});

  final Bill? bill;

  @override
  ConsumerState<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _notesController = TextEditingController();

  late BillType _type;
  /// Na ordem em que foram marcadas: a primeira é a principal.
  late List<BillCategory> _categories;
  late int _installmentCount;
  String? _paidByMemberId;
  Set<String> _participants = {};
  DateTime? _firstDueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;

    _type = bill?.type ?? BillType.fixed;
    _categories = List.of(bill?.categories ?? const [BillCategory.other]);
    _installmentCount = bill?.installmentCount ?? 1;
    _paidByMemberId = bill?.paidByMemberId;
    _participants = {...?bill?.participantIds};
    _firstDueDate = bill?.firstDueDate;

    if (bill != null) {
      _titleController.text = bill.title;
      _notesController.text = bill.notes ?? '';
      MoneyField.setCents(_totalController, bill.totalAmountCents);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _totalCents => Money.parse(_totalController.text);

  bool get _isInstallment => _installmentCount > 1;

  /// Valor de uma parcela. Sempre derivado do total e do número de
  /// parcelas — não é um campo que alguém digita, para o total nunca
  /// divergir da soma das parcelas.
  int get _installmentCents => _isInstallment
      ? Money.divide(_totalCents ?? 0, _installmentCount).first
      : (_totalCents ?? 0);

  /// O total não divide exato: algumas parcelas ficam um centavo menores.
  /// A soma continua batendo com o valor digitado — nada é inventado.
  bool get _unevenInstallments {
    if (!_isInstallment) return false;
    final parts = Money.divide(_totalCents ?? 0, _installmentCount);
    return parts.first != parts.last;
  }

  /// Espelha exatamente o que o app vai gravar, para o usuário conferir
  /// os números antes de salvar.
  Bill _buildBill(String id) => Bill(
        id: id,
        title: _titleController.text.trim(),
        categories: _categories,
        type: _type,
        totalAmountCents: _type == BillType.fixed ? _totalCents : null,
        installmentCount: _isInstallment ? _installmentCount : 1,
        firstDueDate: _firstDueDate,
        paidByMemberId: _paidByMemberId,
        participantIds: _orderedParticipants,
        splitMode: SplitMode.equal,
        status: widget.bill?.status ?? BillStatus.open,
        entriesTotalCents: widget.bill?.entriesTotalCents ?? 0,
        entriesCount: widget.bill?.entriesCount ?? 0,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.bill?.createdAt,
        createdBy: widget.bill?.createdBy ?? ref.read(currentUidProvider),
      );

  /// Mantém a ordem dos participantes igual à da lista de membros, para
  /// as cotas saírem sempre na mesma sequência.
  List<String> get _orderedParticipants {
    final members = ref.read(membersProvider).valueOrNull ?? const <Member>[];
    return members.map((m) => m.id).where(_participants.contains).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_participants.isEmpty) {
      AppToast.warning('Escolha pelo menos um participante');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(billRepositoryProvider);
      final tripId = ref.read(currentTripIdProvider);

      if (widget.bill == null) {
        await repo.createBill(tripId, _buildBill(''));
      } else {
        await repo.updateBill(tripId, _buildBill(widget.bill!.id));
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(
          widget.bill == null ? 'Conta criada!' : 'Conta atualizada',
          icon: Icons.check_circle_rounded,
        );
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
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];

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
                  _TypeSelector(
                    value: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  Gap.vXl,

                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome da conta',
                      hintText: 'Aluguel do Airbnb',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Dê um nome para a conta' : null,
                  ),
                  Gap.vLg,

                  Text('Categorias', style: context.text.labelLarge),
                  Gap.vSm,
                  MultiChoiceChips<BillCategory>(
                    options: BillCategory.values,
                    selected: _categories,
                    labelOf: (c) => c.label,
                    required: true,
                    onChanged: (c) => setState(() => _categories = c),
                  ),
                  Gap.vXl,

                  if (_type == BillType.fixed) ...[
                    MoneyField(
                      controller: _totalController,
                      label: 'Valor total',
                      helper: 'Quanto a conta custou no total',
                      onChanged: (_) => setState(() {}),
                      validator: (_) => (_totalCents ?? 0) <= 0 ? 'Informe o valor' : null,
                    ),
                    if (!_isInstallment)
                      _PerPersonHint(
                        totalCents: _totalCents,
                        participantCount: _participants.length,
                      ),
                    Gap.vLg,
                    _InstallmentSection(
                      count: _installmentCount,
                      installmentCents: _installmentCents,
                      unevenInstallments: _unevenInstallments,
                      firstDueDate: _firstDueDate,
                      participantCount: _participants.length,
                      onCountChanged: (n) => setState(() => _installmentCount = n),
                      onPickDate: _pickFirstDueDate,
                    ),
                  ] else
                    const _AccumulatingHint(),

                  Gap.vXl,
                  Text(
                    _type == BillType.accumulating ? 'Quem costuma pagar' : 'Quem bancou',
                    style: context.text.labelLarge,
                  ),
                  Text(
                    _type == BillType.accumulating
                        ? 'Vem marcado em cada lançamento, e dá para trocar a cada vez'
                        : 'Quem pagou e vai receber as transferências',
                    style: context.text.bodySmall,
                  ),
                  Gap.vSm,
                  _MemberSelector(
                    members: members,
                    selected: _paidByMemberId == null ? {} : {_paidByMemberId!},
                    onToggle: (id) => setState(() {
                      _paidByMemberId = _paidByMemberId == id ? null : id;
                      // Quem banca participa da divisão por padrão.
                      if (_paidByMemberId != null) _participants.add(id);
                    }),
                  ),

                  Gap.vXl,
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dividir entre', style: context.text.labelLarge),
                            Text(
                              '${_participants.length} de ${members.length} participantes',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _participants = _participants.length == members.length
                              ? {}
                              : members.map((m) => m.id).toSet();
                        }),
                        child: Text(
                          _participants.length == members.length ? 'Limpar' : 'Todos',
                        ),
                      ),
                    ],
                  ),
                  Gap.vSm,
                  _MemberSelector(
                    members: members,
                    selected: _participants,
                    multi: true,
                    onToggle: (id) => setState(() {
                      _participants.contains(id)
                          ? _participants.remove(id)
                          : _participants.add(id);
                    }),
                  ),

                  Gap.vXl,
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      hintText: 'Opcional',
                    ),
                  ),

                  if (_participants.isNotEmpty) ...[
                    Gap.vXl,
                    _SplitPreview(bill: _buildBill('preview')),
                  ],
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: widget.bill == null ? 'Criar conta' : 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }

  Future<void> _pickFirstDueDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initialDate: _firstDueDate ?? DateTime(now.year, now.month + 1, 10),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      title: 'Vencimento da 1ª parcela',
    );
    if (picked != null) setState(() => _firstDueDate = picked);
  }
}

// ---------------------------------------------------------------

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final BillType value;
  final ValueChanged<BillType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final type in BillType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: InkWell(
              borderRadius: Radii.brSm,
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: Motion.fast,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: Radii.brSm,
                  border: Border.all(
                    color: value == type ? context.colors.onSurface : context.colors.outline,
                    width: value == type ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: value == type ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(type.description, style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InstallmentSection extends StatelessWidget {
  const _InstallmentSection({
    required this.count,
    required this.installmentCents,
    required this.unevenInstallments,
    required this.firstDueDate,
    required this.participantCount,
    required this.onCountChanged,
    required this.onPickDate,
  });

  final int count;
  final int installmentCents;
  final bool unevenInstallments;
  final DateTime? firstDueDate;
  final int participantCount;
  final ValueChanged<int> onCountChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Parcelamento', style: context.text.labelLarge)),
            Text(
              count == 1 ? 'À vista' : '${count}x',
              style: AppTypography.numeric(size: 13, color: context.colors.onSurface),
            ),
          ],
        ),
        Slider(
          value: count.toDouble(),
          min: 1,
          max: 24,
          divisions: 23,
          label: count == 1 ? 'À vista' : '${count}x',
          onChanged: (v) => onCountChanged(v.round()),
        ),
        if (count > 1) ...[
          Gap.vSm,
          _ComputedInstallment(cents: installmentCents, uneven: unevenInstallments),
          _PerPersonHint(
            totalCents: installmentCents,
            participantCount: participantCount,
            perMonth: true,
          ),
          Gap.vLg,
          InkWell(
            borderRadius: Radii.brSm,
            onTap: onPickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vencimento da 1ª parcela',
                prefixIcon: Icon(Icons.event_outlined, size: 20),
              ),
              child: Text(
                firstDueDate == null
                    ? 'Escolher data'
                    : Fmt.dateShortWithYear(firstDueDate!),
                style: firstDueDate == null
                    ? context.text.bodyMedium?.copyWith(color: AppColors.inkFaint)
                    : AppTypography.numeric(size: 14, color: context.colors.onSurface),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Valor de cada parcela, só de leitura.
///
/// É resultado de conta, não decisão: sai de total ÷ parcelas. Deixar
/// editável abriria espaço para o total divergir da soma das parcelas.
class _ComputedInstallment extends StatelessWidget {
  const _ComputedInstallment({required this.cents, required this.uneven});

  final int cents;

  /// True quando o total não divide exato pelo número de parcelas.
  final bool uneven;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Valor de cada parcela', style: context.text.labelSmall),
          Text(
            cents <= 0 ? '—' : Money.format(cents),
            style: AppTypography.money(size: 18, color: context.colors.onSurface),
          ),
          if (uneven && cents > 0)
            Text(
              'as últimas ficam 1 centavo menores, para o total fechar exato',
              style: context.text.labelSmall,
            ),
        ],
      ),
    );
  }
}

/// Quanto cabe a cada pessoa, ao vivo.
///
/// Recalcula sozinha quando muda o valor, o número de parcelas ou a
/// quantidade de gente na divisão — que é justamente o momento em que
/// a pergunta "quanto vai sobrar para mim?" aparece.
class _PerPersonHint extends StatelessWidget {
  const _PerPersonHint({
    required this.totalCents,
    required this.participantCount,
    this.perMonth = false,
  });

  final int? totalCents;
  final int participantCount;

  /// True quando o valor se repete a cada parcela.
  final bool perMonth;

  @override
  Widget build(BuildContext context) {
    final cents = totalCents ?? 0;

    final Widget content;
    if (participantCount == 0) {
      content = const _Line(
        key: ValueKey('sem-gente'),
        text: 'Escolha os participantes para ver o valor de cada um',
      );
    } else if (cents <= 0) {
      content = const SizedBox(key: ValueKey('sem-valor'), width: double.infinity);
    } else {
      // Mesma divisão usada para gerar as cotas, inclusive na sobra de
      // centavos: o que aparece aqui é exatamente o que será cobrado.
      final parts = Money.divide(cents, participantCount);
      final uneven = parts.first != parts.last;

      content = _Line(
        key: ValueKey('$cents-$participantCount-$perMonth'),
        text: '${Money.format(parts.first)} para cada '
            '${participantCount == 1 ? "pessoa" : "uma das $participantCount pessoas"}'
            '${perMonth ? ", por mês" : ""}'
            '${uneven ? " · um centavo a mais para o primeiro" : ""}',
        emphasis: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: AnimatedSize(
        duration: Motion.fast,
        curve: Motion.enter,
        alignment: Alignment.topCenter,
        child: content,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.text, this.emphasis = false});

  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        style: context.text.bodySmall?.copyWith(
          color: emphasis ? context.colors.onSurface : null,
          fontWeight: emphasis ? FontWeight.w500 : null,
        ),
      ),
    );
  }
}

class _AccumulatingHint extends StatelessWidget {
  const _AccumulatingHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Text(
        'Sem valor por enquanto. Lance cada gasto (cada vez que abastecer, por '
        'exemplo) e feche a conta no final para dividir o total.',
        style: context.text.bodySmall,
      ),
    );
  }
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.members,
    required this.selected,
    required this.onToggle,
    this.multi = false,
  });

  final List<Member> members;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Mantido por compatibilidade: a marca de selecionado é a mesma nos
  /// dois casos — a borda escura do chip.
  final bool multi;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text('Nenhum participante cadastrado', style: context.text.bodySmall);
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final member in members)
          MemberChip(
            member: member,
            selected: selected.contains(member.id),
            onTap: () => onToggle(member.id),
          ),
      ],
    );
  }
}

/// Prévia da divisão: mostra exatamente o que cada um vai pagar.
class _SplitPreview extends ConsumerWidget {
  const _SplitPreview({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersById = ref.watch(membersByIdProvider);
    final total = bill.chargedTotalCents;

    if (total <= 0 && !bill.isAccumulating) {
      return const SizedBox.shrink();
    }

    if (bill.isAccumulating) {
      return _PreviewBox(
        children: [
          Text(
            'Cada lançamento será dividido entre ${bill.participantIds.length} '
            '${bill.participantIds.length == 1 ? "pessoa" : "pessoas"} no fechamento.',
            style: context.text.bodySmall,
          ),
        ],
      );
    }

    final firstInstallment = bill
        .generateShares(tripId: ref.watch(currentTripIdProvider))
        .where((s) => (s.installmentNumber ?? 1) == 1);

    return _PreviewBox(
      children: [
        Row(
          children: [
            Expanded(child: Text('Total cobrado', style: context.text.bodyMedium)),
            Text(
              Money.format(total),
              style: AppTypography.money(size: 15, color: context.colors.onSurface),
            ),
          ],
        ),
        Gap.vMd,
        const Divider(),
        Gap.vMd,
        Text(
          bill.isInstallment
              ? 'Cada um paga por mês, em ${bill.installmentCount}x'
              : 'Cada um paga',
          style: context.text.labelSmall,
        ),
        Gap.vSm,
        for (final share in firstInstallment)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              children: [
                if (membersById[share.memberId] case final member?) ...[
                  MemberAvatar(member: member, size: 20),
                  Gap.hSm,
                ],
                Expanded(
                  child: Text(
                    membersById[share.memberId]?.shortName ?? share.memberId,
                    style: context.text.bodyMedium,
                  ),
                ),
                if (share.isOwnerShare)
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: Text(
                      'bancou',
                      style: context.text.labelSmall?.copyWith(color: context.success),
                    ),
                  ),
                Text(
                  Money.format(share.amountCents),
                  style: AppTypography.money(size: 14, color: context.colors.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
