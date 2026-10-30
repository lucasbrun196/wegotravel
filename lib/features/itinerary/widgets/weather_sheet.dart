import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../data/models/weather.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/layout/app_sheet.dart';

/// O painel de previsão de uma atividade do roteiro.
///
/// Abre por `showAppSheet` como todo o resto: o overlay do Navigator raiz
/// fica fora do escopo da viagem, e é o `showAppSheet` que reembrulha o
/// `ProviderContainer` — sem isso a leitura da previsão falharia aqui
/// dentro.
Future<void> showWeatherSheet(BuildContext context, {required ItineraryItem item}) =>
    showAppSheet(
      context: context,
      title: 'Previsão do tempo',
      subtitle: [
        item.placeName ?? 'Lugar do roteiro',
        Fmt.dateFull(item.date),
      ].join(' · '),
      builder: (_) => WeatherSheet(item: item),
    );

class WeatherSheet extends ConsumerWidget {
  const WeatherSheet({super.key, required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(
      dailyForecastProvider(WeatherQuery(item.lat!, item.lng!)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: forecast.when(
              loading: () => const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShimmerBox(height: 120, borderRadius: Radii.brSm),
                  Gap.vMd,
                  ShimmerBox(height: 76, borderRadius: Radii.brSm),
                  Gap.vMd,
                  ShimmerBox(height: 108, borderRadius: Radii.brSm),
                ],
              ),
              error: (e, _) => ErrorView(
                message: 'Não deu para buscar a previsão',
                details: '$e',
                onRetry: () => ref.invalidate(
                  dailyForecastProvider(WeatherQuery(item.lat!, item.lng!)),
                ),
              ),
              data: (byDay) {
                final day = byDay[Fmt.dayKey(item.date)];
                if (day == null) return const _Unavailable();
                return _Panel(item: item, day: day);
              },
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

/// O dia existe no roteiro, mas não na previsão: passado, ou além dos 16
/// dias que a API alcança.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Ainda não dá para saber',
      message: 'A previsão alcança 16 dias à frente. Este dia está fora desse '
          'alcance, ou já passou. Volte mais perto da data.',
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.item, required this.day});

  final ItineraryItem item;
  final DailyWeather day;

  @override
  Widget build(BuildContext context) {
    final atActivity = item.hasTime ? day.hourNear(item.startAt!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(day: day),
        Gap.vMd,
        _RainVerdict(day: day),

        if (atActivity != null) ...[
          Gap.vMd,
          _AtActivity(item: item, hour: atActivity),
        ],

        Gap.vXl,
        Text('O dia inteiro', style: context.text.labelLarge),
        Gap.vMd,
        _Facts(day: day),

        if (day.hours.isNotEmpty) ...[
          Gap.vXl,
          Text('Hora a hora', style: context.text.labelLarge),
          Gap.vMd,
          _HourStrip(hours: day.hours, highlight: atActivity),
        ],

        Gap.vLg,
        Text(
          'Previsão por Open-Meteo. Quanto mais perto do dia, mais confiável.',
          style: context.text.bodySmall?.copyWith(color: AppColors.inkFaint),
        ),
      ],
    );
  }
}

/// A leitura de um segundo: ícone, condição e as duas temperaturas.
class _Hero extends StatelessWidget {
  const _Hero({required this.day});

  final DailyWeather day;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.onSurface;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border.all(color: context.colors.outline),
        borderRadius: Radii.brSm,
      ),
      child: Row(
        children: [
          Icon(day.condition.icon, size: 36, color: context.colors.onSurfaceVariant),
          Gap.hLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(day.condition.label, style: context.text.titleMedium),
                Gap.vXs,
                Text(
                  day.tempLabel,
                  style: AppTypography.money(size: 28, color: accent),
                ),
                if (day.apparentLabel != null)
                  Text(
                    'sensação de ${day.apparentLabel}',
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

/// A pergunta que todo mundo faz: vai chover?
class _RainVerdict extends StatelessWidget {
  const _RainVerdict({required this.day});

  final DailyWeather day;

  @override
  Widget build(BuildContext context) {
    final wet = day.willRain;
    final accent = context.colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border.all(color: context.colors.outline),
        borderRadius: Radii.brSm,
      ),
      child: Row(
        children: [
          Icon(
            wet ? Icons.umbrella_rounded : Icons.wb_twilight_rounded,
            size: 20,
            color: accent,
          ),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(day.rainVerdict, style: context.text.titleSmall),
                if (day.precipProbability != null)
                  Text(
                    '${day.precipProbability}% de chance'
                    '${day.precipitationMm != null && day.precipitationMm! > 0 ? " · ${day.precipitationMm!.toStringAsFixed(1)} mm previstos" : ""}',
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

/// O recorte que interessa quando a atividade tem horário marcado.
class _AtActivity extends StatelessWidget {
  const _AtActivity({required this.item, required this.hour});

  final ItineraryItem item;
  final HourlyWeather hour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        children: [
          Icon(hour.condition.icon, size: 20, color: context.colors.onSurfaceVariant),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Às ${Fmt.time(item.startAt!)}, na hora de "${item.title}"',
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${hour.tempLabel} · ${hour.condition.label}'
                  '${hour.precipProbability == null ? "" : " · ${hour.precipProbability}% de chuva"}',
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

/// Vento, sol e companhia — o que não coube no resumo.
class _Facts extends StatelessWidget {
  const _Facts({required this.day});

  final DailyWeather day;

  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[
      if (day.precipProbability != null)
        _Fact(
          icon: Icons.water_drop_rounded,
          label: 'Chance de chuva',
          value: '${day.precipProbability}%',
          color: AppColors.sky,
        ),
      if (day.precipitationMm != null)
        _Fact(
          icon: Icons.opacity_rounded,
          label: 'Volume',
          value: '${day.precipitationMm!.toStringAsFixed(1)} mm',
          color: AppColors.deepSea,
        ),
      if (day.windMaxKmh != null)
        _Fact(
          icon: Icons.air_rounded,
          label: 'Vento até',
          value: '${day.windMaxKmh!.round()} km/h',
          color: AppColors.turquoise,
        ),
      if (day.uvIndexMax != null)
        _Fact(
          icon: Icons.wb_sunny_rounded,
          label: 'Índice UV',
          value: '${day.uvIndexMax!.round()} · ${day.uvLabel}',
          color: AppColors.sunset,
        ),
      if (day.sunrise != null)
        _Fact(
          icon: Icons.wb_twilight_rounded,
          label: 'Nascer do sol',
          value: Fmt.time(day.sunrise!),
          color: AppColors.coral,
        ),
      if (day.sunset != null)
        _Fact(
          icon: Icons.nightlight_round,
          label: 'Pôr do sol',
          value: Fmt.time(day.sunset!),
          color: AppColors.grape,
        ),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    // Duas colunas no celular, três a partir do tablet: o sheet é
    // estreito, e três cartões apertados cortam "Nascer do sol".
    final columns = context.isMobile ? 2 : 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - Gap.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final fact in facts) SizedBox(width: width, child: fact),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        border: Border.all(color: context.colors.outline),
        borderRadius: Radii.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
          Gap.vSm,
          Text(
            value,
            style: AppTypography.money(size: 16, color: context.colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: context.text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A curva do dia, hora a hora. Rola na horizontal.
class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.hours, this.highlight});

  final List<HourlyWeather> hours;
  final HourlyWeather? highlight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => Gap.hSm,
        itemBuilder: (context, i) {
          final hour = hours[i];
          final isNow = highlight != null && hour.time == highlight!.time;

          return Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            decoration: BoxDecoration(
              color: isNow
                  ? context.colors.surface
                  : context.colors.surfaceContainerLow,
              borderRadius: Radii.brSm,
              border: isNow
                  ? Border.all(color: context.colors.onSurface, width: 1.5)
                  : Border.all(color: context.colors.outline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  Fmt.time(hour.time),
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: isNow ? FontWeight.w700 : null,
                  ),
                ),
                Icon(hour.condition.icon, size: 18, color: context.colors.onSurfaceVariant),
                Text(
                  hour.tempLabel,
                  style: AppTypography.money(size: 14, color: context.colors.onSurface),
                ),
                Text(
                  hour.precipProbability == null ? '—' : '${hour.precipProbability}%',
                  style: AppTypography.mono(size: 11, color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
