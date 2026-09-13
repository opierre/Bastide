import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import 'mortgage_labels.dart';

/// A dashed vertical on the trajectory: today, or the month a loan ends.
@immutable
class TrajectoryAnnotation {
  const TrajectoryAnnotation({
    required this.month,
    required this.label,
    this.isToday = false,
  });

  final DateTime month;
  final String label;

  /// Today's marker is drawn a step brighter than the end markers.
  final bool isToday;

  @override
  bool operator ==(Object other) =>
      other is TrajectoryAnnotation &&
      other.month == month &&
      other.label == label &&
      other.isToday == isToday;

  @override
  int get hashCode => Object.hash(month, label, isToday);
}

/// « Trajectoire du capital restant dû » (`12-credits.md` §3): the combined
/// outstanding principal of all active loans, month by month to the last
/// instalment, with today and each loan's end annotated.
///
/// What the cards cannot show — when each debt ends, and the step a second loan
/// adds. The series is the API's (`outstanding_series`); no schedule is summed
/// here.
class TrajectoryChartCard extends StatelessWidget {
  const TrajectoryChartCard({
    super.key,
    required this.state,
    required this.today,
  });

  final MortgagesState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final summary = state.summary;
    final series = summary.outstandingSeries;

    final annotations = <TrajectoryAnnotation>[
      for (final point in series)
        if (point.month.year == today.year && point.month.month == today.month)
          TrajectoryAnnotation(
            month: point.month,
            isToday: true,
            label: l10n.mortgagesChartToday(
              DateFormat.yMMMM(locale).format(point.month),
              formatAmount(
                amountMinor: point.outstandingMinor,
                currency: summary.currency,
                locale: locale,
              ),
            ),
          ),
      for (final end in summary.loanEnds)
        TrajectoryAnnotation(
          month: end.month,
          label: l10n.mortgagesChartLoanEnd(switch (state.kindOf(
            end.mortgageId,
          )) {
            final kind? => mortgageKindLabel(l10n, kind).toLowerCase(),
            null => end.label,
          }, mortgageMonthFormat(locale).format(end.month)),
        ),
    ];

    return AppCard(
      key: const Key('trajectoryChartCard'),
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
                      l10n.mortgagesChartTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.mortgagesChartSubtitle(summary.activeCount),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(label: l10n.mortgagesChartLegendTotal, dashed: false),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(label: l10n.mortgagesChartLegendToday, dashed: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TrajectoryPlot(
              key: const Key('trajectoryPlot'),
              months: [for (final point in series) point.month],
              values: [for (final point in series) point.outstandingMinor],
              annotations: annotations,
              yLabel: (minor) => NumberFormat.compactSimpleCurrency(
                locale: locale,
                name: summary.currency,
                decimalDigits: 0,
              ).format(minor / 100),
              labelStyle: AppTextStyles.helper.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.dashed});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 10,
          child: CustomPaint(painter: _LegendSwatchPainter(dashed: dashed)),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(label, style: AppTextStyles.helper),
      ],
    );
  }
}

class _LegendSwatchPainter extends CustomPainter {
  const _LegendSwatchPainter({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = AppColors.iris
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final paint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 3, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LegendSwatchPainter oldDelegate) =>
      oldDelegate.dashed != dashed;
}

/// The plot itself: y gridlines from zero, the iris area line, five-yearly x
/// labels and the dashed annotations. Not animated — charts appear drawn.
class TrajectoryPlot extends StatelessWidget {
  const TrajectoryPlot({
    super.key,
    required this.months,
    required this.values,
    required this.annotations,
    required this.yLabel,
    required this.labelStyle,
  });

  final List<DateTime> months;
  final List<int> values;
  final List<TrajectoryAnnotation> annotations;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrajectoryPainter(
          months: months,
          values: values,
          annotations: annotations,
          yLabel: yLabel,
          labelStyle: labelStyle,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({
    required this.months,
    required this.values,
    required this.annotations,
    required this.yLabel,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<DateTime> months;
  final List<int> values;
  final List<TrajectoryAnnotation> annotations;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  static const _leftGutter = 56.0;
  static const _bottomAxis = 22.0;
  static const _topBand = 20.0;

  int _monthIndex(DateTime month) =>
      (month.year - months.first.year) * 12 + month.month - months.first.month;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
  )..layout();

  /// The gridline step: the smallest 1/2/5 × 10ⁿ that keeps three lines or
  /// fewer under the peak — « 0 · 100 k€ · 200 k€ » for the frame's 255 000 €.
  static int _gridStep(int peak) {
    var magnitude = 1;
    while (true) {
      for (final factor in const [1, 2, 5]) {
        final step = factor * magnitude;
        if (peak / step <= 3) return step;
      }
      magnitude *= 10;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (months.length < 2 || size.width <= _leftGutter) return;

    final peak = values.reduce(math.max);
    final top = math.max(1, (peak * 1.08).round());
    final plot = Rect.fromLTRB(
      _leftGutter,
      _topBand,
      size.width - 4,
      size.height - _bottomAxis,
    );
    final span = math.max(1, _monthIndex(months.last));

    double xOf(DateTime month) =>
        plot.left + plot.width * (_monthIndex(month) / span);
    double yOf(int value) => plot.bottom - plot.height * (value / top);

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    final step = _gridStep(math.max(1, peak));
    for (var value = 0; value <= top; value += step) {
      final y = yOf(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _text(
        yLabel(value),
        labelStyle.copyWith(color: AppColors.textDisabled),
      );
      label.paint(
        canvas,
        Offset(plot.left - label.width - 8, y - label.height / 2),
      );
    }

    for (var year = months.first.year; year <= months.last.year; year++) {
      if (year % 5 != 0) continue;
      final month = DateTime(year);
      if (_monthIndex(month) < 0) continue;
      final label = _text(
        '$year',
        labelStyle.copyWith(color: AppColors.textSecondary),
      );
      label.paint(
        canvas,
        Offset(xOf(month) - label.width / 2, plot.bottom + 5),
      );
    }

    final points = [
      for (var i = 0; i < months.length; i++)
        Offset(xOf(months[i]), yOf(values[i])),
    ];
    final line = Path()..addPolygon(points, false);
    final area = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.iris.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.iris
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (final annotation in annotations) {
      final index = months.indexWhere(
        (month) =>
            month.year == annotation.month.year &&
            month.month == annotation.month.month,
      );
      if (index < 0) continue;
      final point = points[index];
      final color = annotation.isToday
          ? AppColors.textSecondary
          : AppColors.textDisabled;

      final dash = Paint()
        ..color = color
        ..strokeWidth = 1;
      for (var y = plot.top; y < plot.bottom; y += 6) {
        canvas.drawLine(
          Offset(point.dx, y),
          Offset(point.dx, math.min(y + 3, plot.bottom)),
          dash,
        );
      }

      canvas.drawCircle(point, 3.5, Paint()..color = AppColors.surfaceRaised);
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = AppColors.iris
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final label = _text(
        annotation.label,
        labelStyle.copyWith(
          color: annotation.isToday
              ? AppColors.textPrimary
              : AppColors.textDisabled,
        ),
      );
      // Set right of its line, or left of it when that would run off the plot.
      final x = point.dx + 6 + label.width > plot.right
          ? point.dx - 6 - label.width
          : point.dx + 6;
      label.paint(canvas, Offset(x, plot.top - label.height));
    }
  }

  @override
  bool shouldRepaint(_TrajectoryPainter oldDelegate) =>
      !listEquals(oldDelegate.months, months) ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.annotations, annotations) ||
      oldDelegate.labelStyle != labelStyle;
}
