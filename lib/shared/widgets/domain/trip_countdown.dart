import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/trip.dart';

/// Em que pé a viagem está, em palavras: "Faltam 58 dias", "Dia 3 de 8",
/// "Concluída". `null` quando ainda não tem datas.
String? tripCountdownLabel(Trip trip) {
  if (!trip.hasDates) return null;
  if (trip.isUpcoming) {
    final days = trip.daysUntilStart;
    return days == 1 ? 'Começa amanhã' : 'Faltam $days dias';
  }
  if (trip.isOngoing) return 'Dia ${trip.currentDay} de ${trip.totalDays}';
  return 'Concluída';
}

/// O rótulo da contagem com o ponto do sol na frente: amarelo enquanto a
/// viagem acontece, azul enquanto ela não chega, apagado depois que acaba.
class TripCountdown extends StatelessWidget {
  const TripCountdown({super.key, required this.trip, this.style});

  final Trip trip;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = tripCountdownLabel(trip) ?? 'Datas a definir';
    final muted = context.colors.onSurfaceVariant;
    final dot = switch (trip) {
      _ when trip.isOngoing => AppColors.sun,
      _ when trip.isUpcoming => context.colors.primary,
      _ => muted.withValues(alpha: 0.5),
    };
    final base = style ?? context.text.labelMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: base?.copyWith(
              color: trip.isFinished || !trip.hasDates ? muted : context.colors.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
