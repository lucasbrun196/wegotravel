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
import '../../../shared/widgets/domain/category_badge.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import 'itinerary_chip.dart';
import 'itinerary_details_sheet.dart';
import 'itinerary_form_sheet.dart';
import 'weather_chip.dart';

/// Abaixo desta largura o cabeçalho das colunas some.
const _tableBreakpoint = 560.0;

/// Uma atividade como linha de tabela: hora em mono na coluna da esquerda,
/// atividade no meio e o menu de status na ponta. Embaixo do título vêm o
/// endereço, as categorias e o trajeto em etiquetas, e por fim as etiquetas
/// extras (previsão, contas ligadas, link).
///
/// Categoria e transporte já tiveram colunas próprias, de largura fixa: com
/// mais de um valor viravam "Passeio, Jantar, R…". Em etiquetas eles
/// quebram linha em vez de cortar, e cada um tem o seu ícone.
class ItineraryRow extends ConsumerWidget {
  const ItineraryRow({super.key, required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.status == ItineraryStatus.done;
    final cancelled = item.status == ItineraryStatus.cancelled;
    final faded = done || cancelled;
    final muted = context.colors.onSurfaceVariant;

    // Na ordem em que as contas foram ligadas, e sem as que já foram
    // apagadas em Contas.
    final bills = item.isLinkedToBill
        ? {
            for (final b in ref.watch(billsProvider).valueOrNull ?? const <Bill>[]) b.id: b,
          }
        : const <String, Bill>{};
    final linkedBills = [
      for (final id in item.billIds)
        if (bills[id] != null) bills[id]!,
    ];
    final hasLink = item.link != null && item.link!.isNotEmpty;

    final place = [
      item.placeName,
      item.address,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    final tags = <Widget>[
      // Só entra na lista quando pode aparecer: o botão se esconde sozinho,
      // mas um widget vazio ainda ocuparia o `spacing` e empurraria as
      // outras etiquetas para a direita. Sobra o caso do dia fora do
      // horizonte da previsão, que só se sabe depois do pedido.
      if (item.hasCoords && ref.watch(weatherWindowOpenProvider)) WeatherChip(item: item),
      for (final bill in linkedBills)
        ItineraryChip(
          label: '${bill.title} · ${Money.formatCompact(bill.chargedTotalCents)}',
          icon: Icons.receipt_long_outlined,
          color: AppColors.sunset,
        ),
      if (hasLink) _LinkChip(url: item.link!),
    ];

    // Tocar é para consultar; editar fica no menu "...", para um formulário
    // não abrir (e ser salvo) sem querer.
    return InkWell(
      onTap: () => showItineraryDetails(context, item: item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.xs, Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 52, child: _TimeColumn(item: item, faded: faded)),
            CategoryBadge(
              icon: item.category.icon,
              color: item.category.color,
              size: 32,
              faded: faded,
            ),
            Gap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: faded ? muted : null,
                            decoration: cancelled ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (done) ...[
                        Gap.hXs,
                        Icon(Icons.check, size: 14, color: context.success),
                      ],
                    ],
                  ),
                  if (place.isNotEmpty)
                    Text(
                      place,
                      style: context.text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Gap.vSm,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final c in item.categories)
                        ItineraryChip(
                          label: c.label,
                          icon: c.icon,
                          color: faded ? null : c.color,
                        ),
                      if (item.transports.isNotEmpty)
                        TransportRouteChip(transports: item.transports),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    Gap.vSm,
                    Wrap(spacing: 6, runSpacing: 6, children: tags),
                  ],
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    Gap.vSm,
                    Text(
                      item.notes!,
                      style: context.text.bodySmall?.copyWith(color: AppColors.inkFaint),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _StatusButton(item: item),
          ],
        ),
      ),
    );
  }
}


/// A hora de início e, quando há, a de fim embaixo, ligadas por um traço
/// vertical — "das 05:30 às 07:00" lido de cima para baixo. O fim vem num
/// tom mais apagado, para o olho pegar o começo primeiro.
class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.item, required this.faded});

  final ItineraryItem item;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final start = item.startAt;
    final end = item.endAt;
    final strong = faded ? AppColors.inkFaint : context.colors.onSurface;
    final soft = faded ? AppColors.inkFaint : context.colors.onSurfaceVariant;

    final startStyle = AppTypography.mono(size: 13, color: strong);
    if (start == null || end == null || end == start) {
      // A altura de linha centraliza a hora com o selo de categoria (32px).
      return Text(
        start == null ? '—' : Fmt.time(start),
        style: startStyle.copyWith(height: 2.2),
      );
    }

    // Mesma posição da hora sozinha, mas com o espaço todo em cima: embaixo
    // ela encosta no traço. A coluna fica da largura do texto, então o traço
    // cai no meio dele.
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(Fmt.time(start), style: startStyle.copyWith(height: 1.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              width: 1.5,
              height: 14,
              decoration: BoxDecoration(
                color: soft.withValues(alpha: 0.4),
                borderRadius: Radii.brPill,
              ),
            ),
          ),
          Text(Fmt.time(end), style: AppTypography.mono(size: 12, color: soft)),
        ],
      ),
    );
  }
}

/// O cabeçalho das colunas, para quando a tabela tem largura para elas.
class ItineraryTableHeader extends StatelessWidget {
  const ItineraryTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _tableBreakpoint) return const SizedBox.shrink();
        final style = context.text.labelSmall;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.xs, Gap.sm),
              child: Row(
                children: [
                  SizedBox(width: 52, child: Text('Hora', style: style)),
                  // A largura do selo de categoria e do espaço depois dele.
                  const SizedBox(width: 44),
                  Expanded(child: Text('Atividade', style: style)),
                  // A largura do botão de menu das linhas.
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}

/// Marca como feita, cancela ou apaga a atividade.
class _StatusButton extends ConsumerWidget {
  const _StatusButton({required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.status == ItineraryStatus.done;

    return SizedBox(
      width: 40,
      height: 24,
      child: PopupMenuButton<String>(
        tooltip: 'Opções',
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz, size: 18, color: context.colors.onSurfaceVariant),
        onSelected: (value) async {
          final repo = ref.read(itineraryRepositoryProvider);
          final tripId = ref.read(currentTripIdProvider);

          switch (value) {
            case 'feito':
              await repo.setStatus(tripId, item.id, ItineraryStatus.done.name);
            case 'planejado':
              await repo.setStatus(tripId, item.id, ItineraryStatus.planned.name);
            case 'cancelado':
              await repo.setStatus(tripId, item.id, ItineraryStatus.cancelled.name);
            case 'editar':
              if (context.mounted) await showItineraryForm(context, item: item);
            case 'excluir':
              if (context.mounted) await _confirmDelete(context, ref);
          }
        },
        itemBuilder: (context) => [
          if (!done)
            const PopupMenuItem(
              value: 'feito',
              child: _MenuRow(icon: Icons.check, label: 'Marcar como feito'),
            )
          else
            const PopupMenuItem(
              value: 'planejado',
              child: _MenuRow(icon: Icons.undo, label: 'Voltar para planejado'),
            ),
          const PopupMenuItem(
            value: 'editar',
            child: _MenuRow(icon: Icons.edit_outlined, label: 'Editar'),
          ),
          if (item.status != ItineraryStatus.cancelled)
            const PopupMenuItem(
              value: 'cancelado',
              child: _MenuRow(icon: Icons.block, label: 'Cancelar atividade'),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'excluir',
            child: _MenuRow(
              icon: Icons.delete_outline,
              label: 'Excluir',
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir atividade?'),
        content: Text('"${item.title}" sai do roteiro. As contas ligadas a ela continuam '
            'em Contas.'),
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
    if (ok != true) return;

    await ref
        .read(itineraryRepositoryProvider)
        .deleteItem(ref.read(currentTripIdProvider), item.id);
    if (context.mounted) AppToast.success('Atividade excluída');
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        Gap.hMd,
        Text(label, style: context.text.bodyMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: Radii.brSm,
      onTap: () => openActivityLink(context, url),
      child: const ItineraryChip(
        label: 'Abrir link',
        icon: Icons.open_in_new,
        color: AppColors.grape,
      ),
    );
  }
}
