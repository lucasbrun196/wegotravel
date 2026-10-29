import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/itinerary_enums.dart';

/// Como a turma chega, lido como um trajeto: "Carro → Barco". Pílula neutra,
/// para não competir com as categorias, que têm cor. Por dentro é um
/// `Wrap`: num celular estreito o trajeto quebra linha em vez de estourar.
class TransportRouteChip extends StatelessWidget {
  const TransportRouteChip({super.key, required this.transports});

  final List<TransportMode> transports;

  @override
  Widget build(BuildContext context) {
    final fg = context.colors.onSurfaceVariant;
    final style = context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600);

    return Tooltip(
      message: transports.length == 1 ? 'Transporte' : 'Trajeto, na ordem',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: Radii.brPill,
          border: Border.all(color: context.colors.outline),
        ),
        child: Wrap(
          spacing: Gap.xs,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, mode) in transports.indexed) ...[
              if (i > 0)
                Icon(Icons.arrow_forward_rounded, size: 11, color: fg.withValues(alpha: 0.6)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 12, color: fg),
                  const SizedBox(width: 3),
                  Text(mode.label, style: style),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de informação da linha do roteiro: conta ligada, link.
/// Pílula tingida da cor dada; sem cor, fica neutra.
class ItineraryChip extends StatelessWidget {
  const ItineraryChip({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final base = color;
    final fg = base == null
        ? context.colors.onSurfaceVariant
        : dark
            ? Color.lerp(base, Colors.white, 0.3)!
            : Color.lerp(base, Colors.black, 0.2)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: base == null
            ? context.colors.surface
            : base.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: Radii.brPill,
        border: Border.all(
          color: base == null ? context.colors.outline : base.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          Gap.hXs,
          // O `Wrap` não encolhe os filhos: sem o `Flexible`, uma etiqueta
          // mais larga que a linha estoura em vez de quebrar. O nome da
          // conta ligada é justamente o que costuma passar.
          Flexible(
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
