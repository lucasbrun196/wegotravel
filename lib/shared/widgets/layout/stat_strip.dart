import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../feedback/animated_counter.dart';

/// Uma célula da [StatStrip].
class StatCell {
  const StatCell({
    required this.label,
    required this.value,
    this.footnote,
    this.highlight = false,
    this.color,
  }) : cents = null;

  /// Valor em dinheiro: conta de zero até o total quando aparece.
  const StatCell.money({
    required this.label,
    required int this.cents,
    this.footnote,
    this.highlight = false,
    this.color,
  }) : value = '';

  final String label;

  /// Já formatado — contagem, porcentagem. Vazio quando a célula é de
  /// dinheiro ([cents]).
  final String value;
  final int? cents;
  final String? footnote;

  /// Fundo coral claro e texto coral: o número que pede atenção.
  final bool highlight;

  /// O ponto de cor ao lado do rótulo — identifica a coluna de relance.
  final Color? color;
}

/// Faixa única de números, dividida em colunas por linhas finas.
///
/// Substitui a grade de cartões soltos: os valores ficam lado a lado, na
/// mesma linha de base, e se comparam de relance. Quando a largura não dá
/// [minCellWidth] para cada célula, a faixa quebra em linhas de duas.
class StatStrip extends StatelessWidget {
  const StatStrip({
    super.key,
    required this.cells,
    this.minCellWidth = 132,
    this.valueSize = 20,
  });

  final List<StatCell> cells;
  final double minCellWidth;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final line = context.colors.outline;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsInOne = constraints.maxWidth / cells.length >= minCellWidth;
        final perRow = fitsInOne ? cells.length : 2;

        final rows = <List<StatCell>>[
          for (var i = 0; i < cells.length; i += perRow)
            cells.sublist(i, (i + perRow).clamp(0, cells.length)),
        ];

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: Radii.brLg,
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) Divider(height: 1, color: line),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < perRow; c++) ...[
                        if (c > 0) VerticalDivider(width: 1, thickness: 1, color: line),
                        Expanded(
                          child: c < rows[r].length
                              ? _Cell(cell: rows[r][c], valueSize: valueSize)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.valueSize});

  final StatCell cell;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final accent = context.debt;
    final textColor = cell.highlight ? accent : context.colors.onSurface;
    final labelColor = cell.highlight ? accent : context.colors.onSurfaceVariant;

    return Container(
      color: cell.highlight ? context.debtSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (cell.color != null) ...[
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(color: cell.color, borderRadius: Radii.brPill),
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  cell.label,
                  style: context.text.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Gap.vSm,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: cell.cents == null
                ? Text(cell.value, style: AppTypography.money(size: valueSize, color: textColor))
                : AnimatedMoney(
                    cell.cents! / 100,
                    style: AppTypography.money(size: valueSize, color: textColor),
                  ),
          ),
          if (cell.footnote != null) ...[
            Gap.vXs,
            Text(
              cell.footnote!,
              style: AppTypography.numeric(size: 12, color: labelColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
