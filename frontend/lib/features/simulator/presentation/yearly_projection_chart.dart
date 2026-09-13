import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/simulation_result.dart';

/// « Projection annuelle » (`14-simulateur.md` §Projection): one stacked bar per
/// year, capital in iris at the bottom and interest in cyan above it.
///
/// Yearly, never monthly — 300 bars at this width is noise. The split is the
/// API's yearly rows; nothing is summed out of a schedule here. Before anything
/// can be computed the card keeps its place and carries the invitation instead.
class YearlyProjectionCard extends StatelessWidget {
  const YearlyProjectionCard({super.key, required this.result});

  final SimulationResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final result = this.result;

    return AppCard(
      key: const Key('projectionCard'),
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
                      l10n.simulatorChartTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.simulatorChartSubtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(
                label: l10n.simulatorChartCapital,
                color: AppColors.iris,
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendItem(
                label: l10n.simulatorChartInterest,
                color: AppColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: result == null || result.yearly.isEmpty
                ? Center(
                    child: Text(
                      l10n.simulatorChartEmpty,
                      key: const Key('projectionEmpty'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  )
                : YearlyProjectionPlot(
                    key: const Key('projectionPlot'),
                    years: [for (final row in result.yearly) row.year],
                    capital: [
                      for (final row in result.yearly) row.principalMinor,
                    ],
                    interest: [
                      for (final row in result.yearly) row.interestMinor,
                    ],
                    yLabel: (minor) => NumberFormat.compactSimpleCurrency(
                      locale: locale,
                      name: result.currency,
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
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(label, style: AppTextStyles.helper),
      ],
    );
  }
}

/// The StackedBars plot: y gridlines from zero, a bar per year, x labels every
/// fourth year and the last. Not animated — charts appear drawn.
class YearlyProjectionPlot extends StatelessWidget {
  const YearlyProjectionPlot({
    super.key,
    required this.years,
    required this.capital,
    required this.interest,
    required this.yLabel,
    required this.labelStyle,
  });

  final List<int> years;
  final List<int> capital;
  final List<int> interest;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _StackedBarsPainter(
          years: years,
          capital: capital,
          interest: interest,
          yLabel: yLabel,
          labelStyle: labelStyle,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _StackedBarsPainter extends CustomPainter {
  _StackedBarsPainter({
    required this.years,
    required this.capital,
    required this.interest,
    required this.yLabel,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<int> years;
  final List<int> capital;
  final List<int> interest;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  static const _leftGutter = 52.0;
  static const _bottomAxis = 22.0;
  static const _topPad = 8.0;
  static const _stackGap = 2.0;
  static const _maxBarWidth = 44.0;

  TextPainter _text(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: labelStyle.copyWith(color: color),
    ),
    textDirection: textDirection,
  )..layout();

  /// The gridline step: the smallest 1/2/4/5/8 × 10ⁿ that keeps two lines or
  /// so above zero — « 0 · 8 k€ · 16 k€ » for the frame's yearly bars.
  static int _gridStep(int peak) {
    var magnitude = 1;
    while (true) {
      for (final factor in const [1, 2, 4, 5, 8]) {
        final step = factor * magnitude;
        if (peak / step <= 2.5) return step;
      }
      magnitude *= 10;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (years.isEmpty || size.width <= _leftGutter) return;

    // The bar height is the two API figures laid end to end — geometry for
    // the scale, not a figure the panel prints.
    var peak = 1;
    for (var index = 0; index < years.length; index++) {
      peak = math.max(peak, capital[index] + interest[index]);
    }
    final step = _gridStep(peak);
    final top = step * (peak / step).ceil();
    final plot = Rect.fromLTRB(
      _leftGutter,
      _topPad,
      size.width - 4,
      size.height - _bottomAxis,
    );
    double heightOf(int value) => plot.height * (value / top);

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (var value = 0; value <= top; value += step) {
      final y = plot.bottom - heightOf(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _text(yLabel(value), AppColors.textDisabled);
      label.paint(
        canvas,
        Offset(plot.left - label.width - 8, y - label.height / 2),
      );
    }

    final slot = plot.width / years.length;
    final width = math.min(_maxBarWidth, slot * 0.62);
    final capRadius = math.min(6.0, width / 2);
    const baseRadius = Radius.circular(2);
    final capitalPaint = Paint()..color = AppColors.iris;
    final interestPaint = Paint()..color = AppColors.cyan;
    final last = years.length - 1;

    for (var index = 0; index < years.length; index++) {
      final center = plot.left + slot * (index + 0.5);
      final left = center - width / 2;
      final capitalHeight = heightOf(capital[index]);
      final interestHeight = heightOf(interest[index]);

      if (capitalHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              left,
              plot.bottom - capitalHeight,
              width,
              capitalHeight,
            ),
            topLeft: baseRadius,
            topRight: baseRadius,
            bottomLeft: baseRadius,
            bottomRight: baseRadius,
          ),
          capitalPaint,
        );
      }
      if (interestHeight > 0) {
        final bottom = plot.bottom - capitalHeight - _stackGap;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, bottom - interestHeight, width, interestHeight),
            topLeft: Radius.circular(capRadius),
            topRight: Radius.circular(capRadius),
            bottomLeft: baseRadius,
            bottomRight: baseRadius,
          ),
          interestPaint,
        );
      }

      // Every fourth year and the last, dropping a fourth-year label that
      // would crowd the last one.
      final labelled = index == last || (index % 4 == 0 && last - index >= 2);
      if (!labelled) continue;
      final label = _text('${years[index]}', AppColors.textSecondary);
      label.paint(canvas, Offset(center - label.width / 2, plot.bottom + 5));
    }
  }

  @override
  bool shouldRepaint(_StackedBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.years, years) ||
      !listEquals(oldDelegate.capital, capital) ||
      !listEquals(oldDelegate.interest, interest) ||
      oldDelegate.labelStyle != labelStyle;
}
