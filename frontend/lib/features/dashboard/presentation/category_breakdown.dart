import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dashboard_summary.dart';

/// « Dépenses par catégorie » — a donut of the month's expense breakdown plus a legend with
/// amounts, colored to match [CategoryHues] exactly (see `docs/design/04-dashboard.md` §Row 2).
class CategoryBreakdownChart extends StatelessWidget {
  const CategoryBreakdownChart({
    super.key,
    required this.categories,
    required this.currency,
    required this.month,
  });

  final List<CategoryBreakdown> categories;
  final String currency;
  final DateTime month;

  /// Width of the donut column beside the legend at full size, per the spec. The donut itself
  /// is 212 (`r 80 × 2 + stroke 24`), leaving room either side for the column's own gutter.
  static const _donutColumnWidth = 250.0;

  /// The donut's share of the card's width once the card is too narrow for the drawn 250 — the
  /// legend keeps the majority, since it is the part that carries the actual figures.
  static const _donutWidthShare = 0.42;

  /// Below this the ring is no longer a chart, it's a dot: the card stops shrinking the donut
  /// and lets it be the thing that a very small window crops.
  static const _minDonutSize = 96.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final total = categories.fold<int>(0, (sum, category) => sum + category.amountMinor);
    // Highest amount first, so the donut and legend read the same order.
    final sorted = [...categories]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    // The breakdown only ever carries expense rows (see `PROJECT.md` §5), so `kind` is fixed.
    final slugs = [
      for (final category in sorted) categorySlugFor(name: category.name, kind: 'expense'),
    ];
    final colors = [for (final slug in slugs) CategoryHues.forSlug(slug)];

    return ChartContainer(
      title: l10n.dashboardCategoryBreakdownTitle,
      subtitle: l10n.dashboardCategoryBreakdownSubtitle(
        _capitalize(DateFormat.yMMMM(locale).format(month)),
        sorted.length,
      ),
      // The donut is drawn at the spec's 212 whenever the card has room for it, and scales down
      // with the card when it doesn't — a fixed ring in a shrinking card either overflows or
      // eats the legend, and the legend is where the amounts actually are.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final donutSize = _donutSizeFor(constraints);
          // The column keeps the spec's gutter either side of the ring, so a scaled donut stays
          // centred in a column that narrows with it rather than drifting inside a fixed 250.
          final columnWidth =
              donutSize + (_donutColumnWidth - CategoryDonut.size);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: columnWidth,
                child: Center(
                  child: SizedBox(
                    width: donutSize,
                    height: donutSize,
                    child: CategoryDonut(
                      amounts: [for (final category in sorted) category.amountMinor],
                      colors: colors,
                      center: _DonutCenter(total: total, currency: currency),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _Legend(
                  categories: sorted,
                  colors: colors,
                  currency: currency,
                  labels: [for (final row in sorted) localizedCategoryName(l10n, row.name)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The largest donut the card can hold: never above the drawn 212, never below
  /// [_minDonutSize], and bounded by both the height left under the card's title and the share
  /// of the width the legend can spare.
  static double _donutSizeFor(BoxConstraints constraints) {
    final byWidth = constraints.maxWidth * _donutWidthShare;
    final byHeight = constraints.hasBoundedHeight ? constraints.maxHeight : CategoryDonut.size;
    final fits = math.min(byWidth, byHeight);
    return fits.clamp(_minDonutSize, CategoryDonut.size);
  }
}

/// The total spent, and what it is — « 2 214,35 € » over « dépensés ».
class _DonutCenter extends StatelessWidget {
  const _DonutCenter({required this.total, required this.currency});

  final int total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountText(
          amountMinor: total,
          currency: currency,
          // A total is a neutral figure, not an outflow — it stays primary rather than red.
          colorize: false,
          style: textTheme.headlineSmall,
        ),
        Text(
          l10n.dashboardDonutCenterCaption,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// The legend column beside the donut.
///
/// Rows sit on the spec's 34px rhythm, which is exactly what the drawn seven categories need.
/// A user with more categories than that would overflow a fixed 34, so the rhythm is a
/// *maximum*: past the point where they'd no longer fit, the rows tighten evenly rather than
/// the card overflowing or the tail of the list being cut off.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.categories,
    required this.colors,
    required this.labels,
    required this.currency,
  });

  final List<CategoryBreakdown> categories;
  final List<Color> colors;
  final List<String> labels;
  final String currency;

  static const rowHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? math.min(rowHeight, constraints.maxHeight / categories.length)
            : rowHeight;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < categories.length; i++)
              _LegendRow(
                height: height,
                color: colors[i],
                label: labels[i],
                amountMinor: categories[i].amountMinor,
                currency: currency,
                pct: categories[i].pct,
              ),
          ],
        );
      },
    );
  }
}

/// One legend row: swatch · name · amount · share.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.height,
    required this.color,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.pct,
  });

  final double height;

  final Color color;
  final String label;
  final int amountMinor;
  final String currency;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
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
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 46,
            child: Text(
              formatSharePct(pct, locale),
              textAlign: TextAlign.end,
              style: tabularNumberStyle(
                textTheme.bodySmall!,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category's share of the total, to one decimal — « 42,9 % ». Rounding to whole percent
/// collapses the tail of the list, where three categories can all land on the same figure.
String formatSharePct(double pct, String locale) =>
    '${NumberFormat('0.0', locale).format(pct)} %';

/// The donut itself: `r 80`, stroke 24, with a 3px gap between segments.
///
/// Split out from the chart card so the geometry lives in one place — the spec pins these
/// numbers, and a donut drawn at any other radius stops matching the legend beside it.
///
/// Those numbers are the geometry at the drawn [size]; the ring fills whatever box it is given
/// and scales all three in proportion, so a smaller donut is the same drawing at a smaller
/// scale rather than a thick ring squeezed into a narrow one.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.amounts,
    required this.colors,
    this.center,
  });

  final List<int> amounts;
  final List<Color> colors;
  final Widget? center;

  static const radius = 80.0;
  static const stroke = 24.0;
  static const gap = 3.0;

  /// The box the donut occupies. Larger than the ring it contains (`r 80` + `stroke 24` spans
  /// 184): the spec draws the ring on a 212 canvas, and the slack is what keeps the centred
  /// total clear of the ring's inner edge.
  static const size = 212.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        // The largest square that fits inside the ring's *inner* circle — what the centred
        // total has to live in. Sizing it from the ring rather than from the box is what stops
        // the figure colliding with the stroke once the donut scales down.
        final innerBox = (radius - stroke / 2) * 2 * (side / size) / math.sqrt2;

        return CustomPaint(
          painter: _DonutPainter(amounts: amounts, colors: colors),
          child: Center(
            child: SizedBox(
              width: innerBox,
              child: FittedBox(fit: BoxFit.scaleDown, child: center),
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.amounts, required this.colors});

  final List<int> amounts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = amounts.fold<int>(0, (sum, amount) => sum + amount);
    if (total <= 0) return;

    // Radius, stroke, and gap are all read off the box, so the ring is the drawn geometry at
    // whatever scale the card could give it.
    final scale = math.min(size.width, size.height) / CategoryDonut.size;
    final radius = CategoryDonut.radius * scale;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: radius * 2,
      height: radius * 2,
    );
    // The spec's 3px gap is a distance along the ring, so it converts to an angle through the
    // radius rather than being a fixed number of degrees. Scale cancels out — the gap stays the
    // same slice of the circle at every size, which is what keeps the segments proportional.
    final gapAngle = CategoryDonut.gap / CategoryDonut.radius;

    var startAngle = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = (amounts[i] / total) * 2 * math.pi;
      // A segment thinner than the gap it would carve out would invert into a backwards arc,
      // so tiny slices keep a hairline of their own rather than disappearing.
      final drawn = math.max(sweep - gapAngle, gapAngle / 2);
      canvas.drawArc(
        rect,
        startAngle + gapAngle / 2,
        drawn,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = CategoryDonut.stroke * scale
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      !listEquals(oldDelegate.amounts, amounts) || !listEquals(oldDelegate.colors, colors);
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
