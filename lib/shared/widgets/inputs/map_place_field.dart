import 'package:flutter/material.dart';

import '../../../core/config/map_config.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';

/// Atalho para o mapa, usado no roteiro e no destino da viagem.
///
/// O ponto só vai para o banco; o que a pessoa lê é o nome do lugar. Ela
/// continua livre para digitar o lugar à mão no campo de texto ao lado.
class MapPlaceField extends StatelessWidget {
  const MapPlaceField({
    super.key,
    required this.hasPoint,
    required this.placeName,
    required this.onPick,
    required this.onClear,
  });

  final bool hasPoint;
  final String placeName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (!MapConfig.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: Radii.brSm,
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, size: 16, color: context.colors.onSurfaceVariant),
            Gap.hMd,
            Expanded(
              child: Text(
                'O mapa precisa do token do Mapbox '
                '(--dart-define=MAPBOX_TOKEN). Veja o README.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    if (!hasPoint) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('Escolher no mapa'),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: _PickedPlaceRow(
        placeName: placeName,
        onPick: onPick,
        onClear: onClear,
      ),
    );
  }
}

/// O lugar já marcado, com as ações de trocar e tirar do mapa.
///
/// "Trocar" e o "×" comem ~130px: em tela estreita sobra tão pouco que o nome
/// do lugar aparece sempre truncado. Ali as ações descem para a linha de baixo.
class _PickedPlaceRow extends StatelessWidget {
  const _PickedPlaceRow({
    required this.placeName,
    required this.onPick,
    required this.onClear,
  });

  final String placeName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          placeName.trim().isEmpty ? 'Ponto marcado no mapa' : placeName.trim(),
          style: context.text.labelLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text('Marcado no mapa', style: context.text.labelSmall),
      ],
    );

    final swap = TextButton(onPressed: onPick, child: const Text('Trocar'));
    final clear = IconButton(
      tooltip: 'Tirar do mapa',
      onPressed: onClear,
      icon: const Icon(Icons.close_rounded, size: 18),
      visualDensity: VisualDensity.compact,
    );

    if (context.isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: context.colors.onSurfaceVariant),
              Gap.hMd,
              Expanded(child: label),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [swap, clear],
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.place_outlined, size: 18, color: context.colors.onSurfaceVariant),
        Gap.hMd,
        Expanded(child: label),
        swap,
        clear,
      ],
    );
  }
}
