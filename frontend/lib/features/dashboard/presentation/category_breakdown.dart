import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_summary.dart';

/// « Dépenses par catégorie » — a donut of the month's expense breakdown plus a legend with
/// amounts, colored to match [CategoryHues] exactly (see `docs/design/04-dashboard.md`).
class CategoryBreakdownChart extends StatelessWidget {
  const CategoryBreakdownChart({super.key, required this.categories, required this.currency});

  final List<CategoryBreakdown> categories;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = categories.fold<int>(0, (sum, category) => sum + category.amountMinor);
    // Highest amount first, so the donut and legend read the same order.
    final sorted = [...categories]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    // The breakdown only ever carries expense rows (see `PROJECT.md` §5), so `kind` is fixed.
    final slugs = [
      for (final category in sorted) categorySlugFor(name: category.name, kind: 'expense'),
    ];

    return ChartContainer(
      title: l10n.dashboardCategoryBreakdownTitle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _DonutPainter(
                amounts: [for (final category in sorted) category.amountMinor],
                colors: [for (final slug in slugs) CategoryHues.forSlug(slug)],
              ),
              child: Center(
                child: AmountText(
                  amountMinor: total,
                  currency: currency,
                  colorize: false,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _LegendRow(
                    color: CategoryHues.forSlug(slugs[i]),
                    label: localizedCategoryName(l10n, sorted[i].name),
                    amountMinor: sorted[i].amountMinor,
                    currency: currency,
                    pct: sorted[i].pct,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.pct,
  });

  final Color color;
  final String label;
  final int amountMinor;
  final String currency;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        AmountText(
          amountMinor: amountMinor,
          currency: currency,
          colorize: false,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '${pct.round()} %',
            textAlign: TextAlign.end,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Draws the r80/stroke24 donut named in `docs/design/04-dashboard.md`, scaled to the 160px box
/// above. Each slice's sweep is proportional to its share of [amounts]' sum.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.amounts, required this.colors});

  final List<int> amounts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = amounts.fold<int>(0, (sum, amount) => sum + amount);
    if (total <= 0) return;

    final strokeWidth = size.shortestSide * 0.15;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    var startAngle = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = (amounts[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.amounts != amounts || oldDelegate.colors != colors;
}
