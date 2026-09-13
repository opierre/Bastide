import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// `intl` exports a `TextDirection` of its own; the painter needs Flutter's.
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/date_field.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/networth_summary.dart';
import 'networth_summary_card.dart';

/// « Patrimoine net · 12 mois » (`15-synthese.md` §Row 2): the closed-month
/// series as an AreaLine, carrying its caveat inline.
///
/// The chart must not look like it knows something it doesn't: a property has
/// one declared value, so the banner says values are held flat and names the
/// oldest estimate (§18), and a month the API omitted is simply not drawn.
class NetworthSeriesCard extends StatelessWidget {
  const NetworthSeriesCard({super.key, required this.summary});

  final NetWorthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final series = summary.series;
    final monthFormat = networthMonthFormat(locale);
    final oldest = summary.valuedOnOldest;

    return AppCard(
      key: const Key('networthSeriesCard'),
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.networthSeriesTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.networthSeriesSubtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (series.isNotEmpty)
                Text(
                  l10n.networthSeriesRange(
                    monthFormat.format(series.first.month),
                    monthFormat.format(series.last.month),
                  ),
                  key: const Key('networthSeriesRange'),
                  style: AppTextStyles.helper,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: series.isEmpty
                ? Center(
                    child: Text(
                      l10n.networthSeriesEmpty,
                      key: const Key('networthSeriesEmpty'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : NetworthSeriesPlot(
                    key: const Key('networthSeriesPlot'),
                    months: [for (final point in series) point.month],
                    values: [for (final point in series) point.netWorthMinor],
                    currency: summary.currency,
                  ),
          ),
          if (summary.propertyValuesHeldFlat && oldest != null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            _CaveatBanner(
              message: l10n.networthSeriesCaveat(
                appDateFormat(locale).format(oldest),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The info InlineBanner under the chart: blue at 9 % with a 30 % border and
/// the info glyph, its text in the primary ink (`15-synthese.md` §Row 2) — a
/// statement about the data, not an alert.
class _CaveatBanner extends StatelessWidget {
  const _CaveatBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('networthSeriesCaveat'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              key: const Key('networthSeriesCaveatText'),
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The AreaLine itself: an iris 2 px line over a 10 % iris area, 2.5 px ring
/// dots and a 4 px one on the last month, y gridlines at min / mid / max, and
/// a month label under each point.
///
/// Points sit on the calendar, not on their index: a month the API omitted
/// leaves its slot empty, and the line breaks there rather than bridging it —
/// a segment across the gap would draw a value nobody measured.
class NetworthSeriesPlot extends StatelessWidget {
  const NetworthSeriesPlot({
    super.key,
    required this.months,
    required this.values,
    required this.currency,
  });

  /// First day of each month drawn, oldest first — exactly the API's months.
  final List<DateTime> months;

  /// Net worth per month, same length as [months].
  final List<int> values;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final labelStyle = tabularNumberStyle(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondary);

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SeriesPainter(
          months: months,
          values: values,
          monthLabel: DateFormat.MMM(locale).format,
          valueLabel: (minor) => NumberFormat.compactSimpleCurrency(
            locale: locale,
            name: currency,
          ).format(minor / 100).replaceAll('-', '−'),
          labelStyle: labelStyle,
        ),
      ),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.months,
    required this.values,
    required this.monthLabel,
    required this.valueLabel,
    required this.labelStyle,
  });

  final List<DateTime> months;
  final List<int> values;
  final String Function(DateTime) monthLabel;
  final String Function(int) valueLabel;
  final TextStyle labelStyle;

  static const _gutter = 56.0;
  static const _axis = 22.0;
  static const _stroke = 2.0;
  static const _dot = 2.5;
  static const _lastDot = 4.0;
  static const _areaAlpha = 0.10;

  static int _index(DateTime month) => month.year * 12 + month.month - 1;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final plot = Rect.fromLTRB(
      _gutter,
      _lastDot,
      size.width - _lastDot,
      size.height - _axis,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final range = (high - low).toDouble();

    double y(num value) => range == 0
        ? plot.center.dy
        : plot.bottom - plot.height * ((value - low) / range);

    // Gridlines at min / mid / max, labelled in the gutter.
    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    final levels = range == 0 ? [low] : [low, (low + high) ~/ 2, high];
    for (final level in levels) {
      final lineY = y(level);
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(size.width, lineY),
        grid,
      );
      final label = _text(valueLabel(level));
      label.paint(
        canvas,
        Offset(
          plot.left - AppSpacing.sm - label.width,
          lineY - label.height / 2,
        ),
      );
    }

    final first = _index(months.first);
    final span = _index(months.last) - first;
    double x(DateTime month) => span == 0
        ? plot.center.dx
        : plot.left + plot.width * ((_index(month) - first) / span);

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(x(months[i]), y(values[i])),
    ];

    // Contiguous runs of months: the line and its area break at every gap.
    final runs = <List<Offset>>[];
    for (var i = 0; i < points.length; i++) {
      final continues = i > 0 && _index(months[i]) - _index(months[i - 1]) == 1;
      if (continues) {
        runs.last.add(points[i]);
      } else {
        runs.add([points[i]]);
      }
    }

    final area = Paint()..color = AppColors.iris.withValues(alpha: _areaAlpha);
    final line = Paint()
      ..color = AppColors.iris
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final run in runs.where((run) => run.length > 1)) {
      final path = Path()..addPolygon(run, false);
      canvas.drawPath(
        Path.from(path)
          ..lineTo(run.last.dx, plot.bottom)
          ..lineTo(run.first.dx, plot.bottom)
          ..close(),
        area,
      );
      canvas.drawPath(path, line);
    }

    // Ring dots on the card's surface; the last month's is larger.
    final ring = Paint()
      ..color = AppColors.iris
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final hole = Paint()..color = AppColors.surfaceRaised;
    for (var i = 0; i < points.length; i++) {
      final radius = i == points.length - 1 ? _lastDot : _dot;
      canvas.drawCircle(points[i], radius, hole);
      canvas.drawCircle(points[i], radius, ring);
    }

    // A month label under each point drawn — none under an omitted month.
    for (var i = 0; i < points.length; i++) {
      final label = _text(monthLabel(months[i]));
      label.paint(
        canvas,
        Offset(points[i].dx - label.width / 2, plot.bottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_SeriesPainter oldDelegate) =>
      !listEquals(oldDelegate.months, months) ||
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.labelStyle != labelStyle;
}
