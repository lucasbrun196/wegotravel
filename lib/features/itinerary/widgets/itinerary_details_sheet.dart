import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/destinations.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/itinerary_enums.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../data/models/weather.dart';
import '../../../shared/widgets/domain/category_badge.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import 'itinerary_chip.dart';
import 'weather_sheet.dart';

/// A ficha de uma atividade, só para ler: quando, o que é, como chega, a
/// previsão do dia e as contas ligadas. É o que abre ao tocar numa linha do
/// roteiro; editar fica no menu "..." da linha.
///
/// Abre por `showAppSheet` como todo o resto — a previsão e as contas são
/// lidas do escopo da viagem.
Future<void> showItineraryDetails(BuildContext context, {required ItineraryItem item}) {
  final place = [item.placeName, item.address].where((s) => s != null && s.isNotEmpty);

  return showAppSheet(
    context: context,
    title: item.title,
    subtitle: place.isEmpty ? null : place.join(' · '),
    builder: (_) => ItineraryDetailsSheet(item: item),
  );
}

/// Abre o link de uma atividade fora do app. Aceita o endereço sem
/// `https://`, do jeito que as pessoas costumam colar.
Future<void> openActivityLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) AppToast.error('Não deu para abrir o link');
}

class ItineraryDetailsSheet extends StatelessWidget {
  const ItineraryDetailsSheet({super.key, required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final notes = item.notes ?? '';
    final link = item.link ?? '';

    // Cada bloco entra um pouco depois do anterior.
    var index = 0;
    Widget enter(Widget child) => FadeSlideIn(index: index++, child: child);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                enter(_WhenCard(item: item)),
                if (notes.isNotEmpty)
                  enter(
                    _Section(
                      title: 'Descrição',
                      child: Text(notes, style: context.text.bodyMedium?.copyWith(height: 1.5)),
                    ),
                  ),
                enter(
                  _Section(
                    title: item.transports.isEmpty ? 'Categorias' : 'Categorias e transporte',
                    child: _KindBlock(item: item),
                  ),
                ),
                enter(_WeatherSection(item: item)),
                enter(_BillsSection(item: item)),
                if (link.isNotEmpty)
                  enter(
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xl),
                      child: OutlinedButton.icon(
                        onPressed: () => openActivityLink(context, link),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Abrir link'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Fechar',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Um bloco da ficha: título pequeno, conteúdo embaixo.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.labelLarge)),
              ?trailing,
            ],
          ),
          Gap.vSm,
          child,
        ],
      ),
    );
  }
}

/// Uma linha apagada que explica por que algo não está ali.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        Gap.hSm,
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    );
  }
}

/// O quando, em destaque: o dia por extenso, o horário como intervalo com a
/// duração ao lado, e a situação da atividade. O fundo leva um degradê da
/// cor da categoria principal.
class _WhenCard extends StatelessWidget {
  const _WhenCard({required this.item});

  final ItineraryItem item;

  /// "8h20", "1h", "45 min". Fim antes do início é atividade que passa da
  /// meia-noite: o fim é do dia seguinte.
  static String? _duration(ItineraryItem item) {
    final start = item.startAt, end = item.endAt;
    if (start == null || end == null || end == start) return null;
    var d = end.difference(start);
    if (d.isNegative) d += const Duration(days: 1);
    final h = d.inHours, m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = item.category.color;
    final dark = context.isDark;
    final muted = context.colors.onSurfaceVariant;
    final day = Fmt.dateFull(item.date);
    final duration = _duration(item);
    final timeStyle = AppTypography.numeric(
      size: 16,
      weight: FontWeight.w600,
      color: context.colors.onSurface,
    );

    final status = item.status;
    final statusIcon = switch (status) {
      ItineraryStatus.planned => Icons.schedule_rounded,
      ItineraryStatus.done => Icons.check_circle_rounded,
      ItineraryStatus.cancelled => Icons.block_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.brMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: Color.alphaBlend(color.withValues(alpha: dark ? 0.16 : 0.08), context.colors.surface),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryBadge(icon: item.category.icon, color: color, size: 44),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day[0].toUpperCase()}${day.substring(1)}',
                  style: context.text.titleSmall,
                ),
                Gap.vXs,
                if (!item.hasTime)
                  Text('Sem horário marcado', style: context.text.bodySmall)
                else
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(Fmt.time(item.startAt!), style: timeStyle),
                      if (duration != null) ...[
                        Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
                        Text(Fmt.time(item.endAt!), style: timeStyle),
                        ItineraryChip(label: duration, icon: Icons.timelapse_rounded),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          Gap.hSm,
          ItineraryChip(label: status.label, icon: statusIcon, color: status.color),
        ],
      ),
    );
  }
}

/// Categorias em etiquetas coloridas e o trajeto, cada um com seu rótulo.
class _KindBlock extends StatelessWidget {
  const _KindBlock({required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in item.categories)
              ItineraryChip(label: c.label, icon: c.icon, color: c.color),
          ],
        ),
        if (item.transports.isNotEmpty) ...[
          Gap.vMd,
          Row(
            children: [
              Text('Como chegar', style: context.text.bodySmall),
              Gap.hSm,
              Flexible(child: TransportRouteChip(transports: item.transports)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A previsão do dia, em resumo, com o caminho para o painel completo.
///
/// Segue as mesmas regras do `WeatherChip` — e, quando não há previsão,
/// diz por quê, em vez de sumir: aqui a pessoa veio ler sobre o dia.
class _WeatherSection extends ConsumerWidget {
  const _WeatherSection({required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider).valueOrNull;
    // Sem datas não há janela para explicar; depois da viagem, nada a prever.
    if (trip == null || !trip.hasDates || trip.isFinished) return const SizedBox.shrink();

    final Widget child;
    if (!item.hasCoords) {
      child = const _Note(
        icon: Icons.location_off_outlined,
        text: 'Fixe o lugar no mapa, ao editar a atividade, para ver a previsão.',
      );
    } else if (!ref.watch(weatherWindowOpenProvider)) {
      final opens = trip.startDate!.subtract(const Duration(days: Weather.daysBefore));
      child = _Note(
        icon: Icons.event_available_outlined,
        text: 'A previsão aparece ${Weather.daysBefore} dias antes da viagem, '
            'a partir de ${Fmt.dateShort(opens)}.',
      );
    } else {
      final forecast = ref.watch(dailyForecastProvider(WeatherQuery(item.lat!, item.lng!)));
      child = forecast.when(
        loading: () => const ShimmerBox(height: 64, borderRadius: Radii.brMd),
        error: (_, _) => const _Note(
          icon: Icons.cloud_off_rounded,
          text: 'Não deu para buscar a previsão agora.',
        ),
        data: (byDay) {
          final day = byDay[Fmt.dayKey(item.date)];
          if (day == null) {
            return const _Note(
              icon: Icons.cloud_off_rounded,
              text: 'Este dia ainda está fora do alcance da previsão, que cobre 16 dias.',
            );
          }
          return _WeatherSummary(day: day, onTap: () => showWeatherSheet(context, item: item));
        },
      );
    }

    return _Section(
      title: 'Previsão do tempo',
      // A troca entre o carregando e o resultado não pisca.
      child: AnimatedSwitcher(duration: Motion.normal, child: child),
    );
  }
}

class _WeatherSummary extends StatelessWidget {
  const _WeatherSummary({required this.day, required this.onTap});

  final DailyWeather day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;

    return Material(
      color: context.colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.brMd,
        side: BorderSide(color: context.colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(day.condition.icon, size: 30, color: day.condition.color),
              Gap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.condition.label, style: context.text.titleSmall),
                    Text(
                      [
                        day.rainVerdict,
                        if (day.precipProbability != null) '${day.precipProbability}% de chance',
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(day.tempLabel, style: AppTypography.money(size: 15, color: context.colors.onSurface)),
              Gap.hSm,
              Icon(Icons.chevron_right_rounded, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// As contas ligadas à atividade, com o total no título. Cada uma leva à
/// tela da conta.
class _BillsSection extends ConsumerWidget {
  const _BillsSection({required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Na ordem em que foram ligadas, e sem as que já foram apagadas.
    final byId = {
      for (final b in ref.watch(billsProvider).valueOrNull ?? const <Bill>[]) b.id: b,
    };
    final bills = [
      for (final id in item.billIds)
        if (byId[id] != null) byId[id]!,
    ];
    final total = bills.fold<int>(0, (sum, b) => sum + b.chargedTotalCents);

    return _Section(
      title: 'Contas vinculadas',
      trailing: bills.isEmpty
          ? null
          : Text(Money.format(total), style: AppTypography.money(size: 13, color: context.colors.onSurface)),
      child: bills.isEmpty
          ? const _Note(
              icon: Icons.receipt_long_outlined,
              text: 'Nenhuma conta ligada. Dá para ligar ao editar a atividade.',
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: Radii.brMd,
                border: Border.all(color: context.colors.outline),
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: Radii.brMd,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, bill) in bills.indexed) ...[
                      if (i > 0) const Divider(),
                      _BillLine(bill: bill),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _BillLine extends ConsumerWidget {
  const _BillLine({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settled = bill.status == BillStatus.settled;

    return InkWell(
      onTap: () {
        // A ficha está no overlay do Navigator raiz: fecha primeiro e só
        // depois troca de tela, pelo router guardado antes de fechar.
        final router = GoRouter.of(context);
        final tripId = ref.read(currentTripIdProvider);
        Navigator.of(context).pop();
        router.go('${Routes.tripSection(tripId, AppDestination.expenses)}/${bill.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        child: Row(
          children: [
            CategoryBadge(icon: bill.category.icon, color: bill.category.color, size: 32),
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
                    bill.status.label,
                    style: context.text.labelSmall?.copyWith(
                      color: settled ? context.success : AppColors.sunset,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Money.format(bill.chargedTotalCents),
              style: AppTypography.money(size: 13, color: context.colors.onSurface),
            ),
            Gap.hXs,
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
