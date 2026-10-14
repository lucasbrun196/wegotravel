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
import '../../../data/models/itinerary_enums.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../data/services/geocoding_service.dart';
import '../../../shared/widgets/inputs/date_range_dialog.dart';
import '../../../shared/widgets/inputs/map_place_field.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/inputs/multi_choice_chips.dart';
import 'map_picker_sheet.dart';

Future<void> showItineraryForm(
  BuildContext context, {
  ItineraryItem? item,
  DateTime? suggestedDate,
}) =>
    showAppSheet(
      context: context,
      title: item == null ? 'Nova atividade' : 'Editar atividade',
      subtitle: item == null
          ? 'O que, onde, quando e como chegar'
          : item.title,
      builder: (_) => ItineraryFormSheet(item: item, suggestedDate: suggestedDate),
    );

class ItineraryFormSheet extends ConsumerStatefulWidget {
  const ItineraryFormSheet({super.key, this.item, this.suggestedDate});

  final ItineraryItem? item;

  /// Dia já escolhido quando o usuário adiciona a partir de um dia
  /// específico da timeline.
  final DateTime? suggestedDate;

  @override
  ConsumerState<ItineraryFormSheet> createState() => _ItineraryFormSheetState();
}

class _ItineraryFormSheetState extends ConsumerState<ItineraryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _placeController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _linkController = TextEditingController();

  late DateTime _date;
  /// Na ordem em que foram marcadas: a primeira é a principal.
  late List<ItineraryCategory> _categories;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<TransportMode> _transports = [];

  /// Contas ligadas, na ordem em que foram escolhidas — é a ordem em que
  /// os chips aparecem no card do roteiro.
  final _billIds = <String>[];

  /// A coordenada escolhida no mapa. Só existe no banco — a tela mostra
  /// o nome do lugar.
  double? _lat;
  double? _lng;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _date = item?.date ?? widget.suggestedDate ?? _defaultDate();
    _categories = List.of(item?.categories ?? const [ItineraryCategory.other]);
    _transports = List.of(item?.transports ?? const []);
    _billIds.addAll(item?.billIds ?? const []);
    _lat = item?.lat;
    _lng = item?.lng;

    if (item != null) {
      _titleController.text = item.title;
      _placeController.text = item.placeName ?? '';
      _addressController.text = item.address ?? '';
      _notesController.text = item.notes ?? '';
      _linkController.text = item.link ?? '';
      if (item.startAt != null) _startTime = TimeOfDay.fromDateTime(item.startAt!);
      if (item.endAt != null) _endTime = TimeOfDay.fromDateTime(item.endAt!);
    }
  }

  /// Começa no primeiro dia da viagem — é onde a pessoa quer cadastrar
  /// na maior parte das vezes.
  DateTime _defaultDate() {
    final trip = ref.read(tripProvider).valueOrNull;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = trip?.startDate;
    if (start == null) return today;
    final startDay = DateTime(start.year, start.month, start.day);
    return startDay.isAfter(today) ? startDay : today;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  DateTime? get _startAt => _startTime == null
      ? null
      : DateTime(_date.year, _date.month, _date.day, _startTime!.hour, _startTime!.minute);

  DateTime? get _endAt => _endTime == null
      ? null
      : DateTime(_date.year, _date.month, _date.day, _endTime!.hour, _endTime!.minute);

  String? _trimmed(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  PickedPlace? get _pickedPlace => (_lat == null || _lng == null)
      ? null
      : PickedPlace(
          lat: _lat!,
          lng: _lng!,
          name: _placeController.text.trim().isEmpty
              ? 'Ponto escolhido no mapa'
              : _placeController.text.trim(),
          address: _trimmed(_addressController),
        );

  /// Soma das contas escolhidas, ignorando as que sumiram de Contas.
  int _selectedCents(List<Bill> bills) {
    final byId = {for (final b in bills) b.id: b};
    return _billIds.fold<int>(
      0,
      (sum, id) => sum + (byId[id]?.chargedTotalCents ?? 0),
    );
  }

  /// Onde o mapa abre sem ponto marcado: a última atividade que tenha
  /// coordenada, senão o destino da viagem.
  ({double lat, double lng})? get _mapNear {
    final items = ref.read(itineraryProvider).valueOrNull ?? const <ItineraryItem>[];
    for (final item in items.reversed) {
      if (item.hasCoords) return (lat: item.lat!, lng: item.lng!);
    }
    final trip = ref.read(tripProvider).valueOrNull;
    if (trip != null && trip.hasDestinationCoords) {
      return (lat: trip.destinationLat!, lng: trip.destinationLng!);
    }
    return null;
  }

  Future<void> _pickOnMap() async {
    final place = await showMapPicker(context, initial: _pickedPlace, near: _mapNear);
    if (!mounted || place == null) return;
    setState(() {
      _lat = place.lat;
      _lng = place.lng;
      _placeController.text = place.name;
      // Sempre sobrescreve: o endereço que estava aqui era do ponto
      // antigo, e manter o antigo ao lado de um ponto novo é pior do que
      // deixar o campo vazio para a pessoa preencher.
      _addressController.text = place.address ?? '';
    });
  }

  Future<void> _pickDate() async {
    final trip = ref.read(tripProvider).valueOrNull;
    final picked = await showAppDatePicker(
      context,
      initialDate: _date,
      firstDate: trip?.startDate ?? DateTime(_date.year - 1),
      lastDate: trip?.endDate ?? DateTime(_date.year + 2),
      title: 'Que dia é a atividade?',
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ??
          const TimeOfDay(hour: 9, minute: 0),
      helpText: isStart ? 'Começa que horas?' : 'Termina que horas?',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final existing = widget.item;
      final item = ItineraryItem(
        id: existing?.id ?? '',
        title: _titleController.text.trim(),
        date: _date,
        categories: _categories,
        startAt: _startAt,
        endAt: _endAt,
        placeName: _trimmed(_placeController),
        address: _trimmed(_addressController),
        lat: _lat,
        lng: _lng,
        transports: _transports,
        billIds: List.of(_billIds),
        notes: _trimmed(_notesController),
        link: _trimmed(_linkController),
        status: existing?.status ?? ItineraryStatus.planned,
        order: existing?.order ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        createdBy: existing?.createdBy ?? ref.read(currentUidProvider),
        createdAt: existing?.createdAt,
      );

      await ref
          .read(itineraryRepositoryProvider)
          .saveItem(ref.read(currentTripIdProvider), item);

      if (mounted) {
        Navigator.of(context).pop();
        context.showSnack(
          existing == null ? 'Atividade adicionada!' : 'Atividade atualizada',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnack('Não deu para salvar: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billsProvider).valueOrNull ?? const <Bill>[];

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
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'O que vamos fazer',
                      hintText: 'Trilha da Lagoinha do Leste',
                      prefixIcon: Icon(Icons.flag_outlined, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Diga o que é a atividade' : null,
                  ),
                  Gap.vLg,

                  Text('Categorias', style: context.text.labelLarge),
                  Gap.vSm,
                  MultiChoiceChips<ItineraryCategory>(
                    options: ItineraryCategory.values,
                    selected: _categories,
                    labelOf: (c) => c.label,
                    required: true,
                    onChanged: (c) => setState(() => _categories = c),
                  ),
                  Gap.vXl,

                  // ----- Quando -----
                  Text('Quando', style: context.text.labelLarge),
                  Gap.vMd,
                  InkWell(
                    borderRadius: Radii.brSm,
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Dia',
                        prefixIcon: Icon(Icons.event_rounded, size: 20),
                      ),
                      child: Text(Fmt.dateFull(_date), style: context.text.bodyMedium),
                    ),
                  ),
                  Gap.vMd,
                  _TimeRow(
                    startTime: _startTime,
                    endTime: _endTime,
                    onPickStart: () => _pickTime(isStart: true),
                    onPickEnd: () => _pickTime(isStart: false),
                    onClear: () => setState(() {
                      _startTime = null;
                      _endTime = null;
                    }),
                  ),
                  Gap.vXl,

                  // ----- Onde -----
                  Text('Onde', style: context.text.labelLarge),
                  Gap.vMd,
                  MapPlaceField(
                    hasPoint: _lat != null,
                    placeName: _placeController.text,
                    onPick: _pickOnMap,
                    onClear: () => setState(() {
                      _lat = null;
                      _lng = null;
                    }),
                  ),
                  Gap.vMd,
                  TextFormField(
                    controller: _placeController,
                    textCapitalization: TextCapitalization.words,
                    // Mantém o nome do ponto marcado em dia com o campo.
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Lugar',
                      hintText: 'Pântano do Sul',
                      prefixIcon: Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                  Gap.vMd,
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Endereço',
                      hintText: 'Opcional — rua, referência, ponto de encontro',
                      prefixIcon: Icon(Icons.signpost_outlined, size: 20),
                    ),
                  ),
                  Gap.vXl,

                  // ----- Como chega -----
                  Row(
                    children: [
                      Expanded(child: Text('Como vamos', style: context.text.labelLarge)),
                      if (_transports.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(_transports.clear),
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  Gap.vSm,
                  MultiChoiceChips<TransportMode>(
                    options: TransportMode.values,
                    selected: _transports,
                    labelOf: (t) => t.label,
                    onChanged: (t) => setState(() => _transports = t),
                  ),
                  Gap.vXl,

                  // ----- Contas vinculadas -----
                  Row(
                    children: [
                      Expanded(
                        child: Text('Contas relacionadas', style: context.text.labelLarge),
                      ),
                      if (_billIds.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(_billIds.clear),
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  Text(
                    'Ligue quantas contas quiser — todas entram nas estatísticas '
                    'do roteiro',
                    style: context.text.bodySmall,
                  ),
                  Gap.vMd,
                  _BillPicker(
                    bills: bills,
                    selectedIds: _billIds,
                    onToggle: (id) => setState(() {
                      if (!_billIds.remove(id)) _billIds.add(id);
                    }),
                  ),
                  if (_billIds.length > 1) ...[
                    Gap.vSm,
                    Text(
                      '${_billIds.length} contas · '
                      '${Money.format(_selectedCents(bills))} no total',
                      style: context.text.labelSmall,
                    ),
                  ],
                  Gap.vXl,

                  TextFormField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Link',
                      hintText: 'Opcional — reserva, mapa, site',
                      prefixIcon: Icon(Icons.link_rounded, size: 20),
                    ),
                  ),
                  Gap.vLg,
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      hintText: 'Opcional — levar protetor, chegar cedo...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: widget.item == null ? 'Adicionar' : 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------

/// Horário é opcional: enquanto ninguém define, a atividade é "algum
/// momento do dia" e vai para o fim da lista daquele dia.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.startTime,
    required this.endTime,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (startTime == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onPickStart,
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Definir horário'),
          ),
          Gap.vSm,
          Text(
            'Sem horário, a atividade fica como "algum momento do dia" '
            'e aparece no fim daquele dia.',
            style: context.text.labelSmall,
          ),
        ],
      );
    }

    final start = InkWell(
      borderRadius: Radii.brSm,
      onTap: onPickStart,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Começa',
          prefixIcon: Icon(Icons.schedule, size: 20),
        ),
        child: Text(
          startTime!.format(context),
          style: AppTypography.mono(size: 14, color: context.colors.onSurface),
        ),
      ),
    );

    final end = InkWell(
      borderRadius: Radii.brSm,
      onTap: onPickEnd,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Termina'),
        child: Text(
          endTime?.format(context) ?? 'opcional',
          style: endTime == null
              ? context.text.bodyMedium?.copyWith(color: AppColors.inkFaint)
              : context.text.bodyMedium,
        ),
      ),
    );

    final clear = IconButton(
      tooltip: 'Tirar horário',
      onPressed: onClear,
      icon: const Icon(Icons.close_rounded, size: 18),
      visualDensity: VisualDensity.compact,
    );

    // Lado a lado em tela estreita sobram ~60px por campo — e o de início
    // ainda tem o ícone. O label flutuante não cabe. Empilhados, cada um usa
    // a largura toda.
    if (context.isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          start,
          Gap.vSm,
          Row(
            children: [Expanded(child: end), Gap.hXs, clear],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: start),
        Gap.hMd,
        Expanded(child: end),
        Gap.hXs,
        clear,
      ],
    );
  }
}

class _BillPicker extends StatelessWidget {
  const _BillPicker({
    required this.bills,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Bill> bills;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: Radii.brSm,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
            Gap.hMd,
            Expanded(
              child: Text(
                'Nenhuma conta cadastrada ainda. Crie em Contas e volte aqui para ligar.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final bill in bills)
          _selectable(context, bill, selected: selectedIds.contains(bill.id)),
      ],
    );
  }

  /// Cada conta é um botão de liga/desliga: dá para marcar quantas forem.
  Widget _selectable(BuildContext context, Bill bill, {required bool selected}) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onToggle(bill.id),
      // Dentro de um `Wrap` o título da conta precisa poder encolher: sem
      // o limite, um nome longo estoura a linha.
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          '${bill.title} · ${Money.formatCompact(bill.chargedTotalCents)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
