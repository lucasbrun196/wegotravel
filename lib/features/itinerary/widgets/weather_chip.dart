import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/itinerary_item.dart';
import '../../../data/models/weather.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import 'weather_sheet.dart';

/// Como o tempo deve estar no dia da atividade, no lugar dela.
///
/// É também o botão que abre o painel completo do dia
/// (`showWeatherSheet`): chuva, vento, UV, sol e a curva hora a hora.
///
/// Some sozinho — sem mensagem de erro, sem espaço vazio — em todos os
/// casos em que não há o que dizer:
///
/// - a atividade não tem lugar fixado no mapa (não há coordenada);
/// - falta mais de uma semana para a viagem começar, ou ela já acabou;
/// - o dia está além do horizonte da API, ou a rede falhou.
class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key, required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!item.hasCoords) return const SizedBox.shrink();
    if (!ref.watch(weatherWindowOpenProvider)) return const SizedBox.shrink();

    final forecast = ref.watch(
      dailyForecastProvider(WeatherQuery(item.lat!, item.lng!)),
    );

    return forecast.when(
      loading: () => const ShimmerBox(
        width: 120,
        height: 22,
        borderRadius: Radii.brPill,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (byDay) {
        final day = byDay[Fmt.dayKey(item.date)];
        if (day == null) return const SizedBox.shrink();

        return _WeatherButton(
          day: day,
          onTap: () => showWeatherSheet(context, item: item),
        );
      },
    );
  }
}

/// O botão em si.
///
/// Não usa o `ItineraryChip` de propósito: os outros chips da linha são
/// etiquetas passivas, e este abre uma tela. A borda, o rótulo "Ver
/// previsão" e a seta são o que separa um do outro à primeira vista — sem
/// eles a temperatura sozinha parecia só mais uma etiqueta.
class _WeatherButton extends StatelessWidget {
  const _WeatherButton({required this.day, required this.onTap});

  final DailyWeather day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = day.condition.color;
    final muted = context.isDark
        ? Color.lerp(tint, Colors.white, 0.3)!
        : Color.lerp(tint, Colors.black, 0.25)!;

    return Tooltip(
      message: '${day.detail}\nVer a previsão completa do dia',
      // O `InkWell` também segura o toque: sem ele, o gesto vazaria
      // para a linha e abriria o formulário da atividade.
      child: InkWell(
        borderRadius: Radii.brPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(Gap.sm, 3, Gap.xs, 3),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: context.isDark ? 0.22 : 0.14),
            borderRadius: Radii.brPill,
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(day.condition.icon, size: 13, color: muted),
              Gap.hXs,
              Text(
                day.tempLabel,
                style: AppTypography.numeric(size: 12, weight: FontWeight.w600, color: muted),
              ),
              Gap.hSm,
              // Em 320px o botão é o mais largo da linha, e sem o
              // `Flexible` ele estoura o `Wrap`.
              Flexible(
                child: Text(
                  'Previsão',
                  style: context.text.labelSmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
