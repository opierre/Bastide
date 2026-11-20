import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/simulation_result.dart';

/// « Projection annuelle » (`14-simulateur.md` §Reading pane, 5): one stacked
/// bar per year, capital in `accent` at the base and interest in
/// `textTertiary` above it, with the legend on the heading line.
///
/// Yearly, never monthly: 300 bars at this width is noise. The split is the
/// API's yearly rows; nothing is summed out of a schedule here. Before
/// anything can be computed the block keeps its place and carries a note.
class YearlyProjection extends StatelessWidget {
  const YearlyProjection({super.key, required this.result});

  final SimulationResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final result = this.result;

    return Column(
      key: const Key('projection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.simulatorChartTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendItem(
                label: l10n.simulatorChartCapital,
                color: context.colors.accent,
              ),
              const SizedBox(width: AppSpacing.smPlus),
              _LegendItem(
                label: l10n.simulatorChartInterest,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: result == null || result.yearly.isEmpty
              ? Align(
                  alignment: AlignmentDirectional.topStart,
                  child: NoteLine(
                    key: const Key('projectionEmpty'),
                    text: l10n.simulatorChartEmpty,
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
                  labelStyle: ChartPaints.labelStyle(context),
                  // The year, then its two API figures: neutral, like every
                  // amount on this panel.
                  tooltips: [
                    for (final row in result.yearly)
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${row.year}\n',
                            style: tabularNumberStyle(textTheme.labelSmall!),
                          ),
                          TextSpan(
                            text:
                                '${l10n.simulatorChartTooltipCapital(formatAmount(amountMinor: row.principalMinor, currency: result.currency, locale: locale))}\n'
                                '${l10n.simulatorChartTooltipInterest(formatAmount(amountMinor: row.interestMinor, currency: result.currency, locale: locale))}',
                            style: tabularNumberStyle(textTheme.bodySmall!),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A legend entry as a category label (`00` §9): an 8 px square dot, radius
/// 2, in the series colour, and the name 12 `textSecondary`.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.bar),
          ),
        ),
        const SizedBox(width: AppSpacing.xsPlus),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// The StackedBars plot, framed in the shared curve style ([AppChart]):
/// labelled y gridlines on clean ticks from zero (see [ChartScale]), a bar per
/// year, x labels every fourth year and the last, and the chart card on hover.
/// Not animated — charts appear drawn.
class YearlyProjectionPlot extends StatefulWidget {
  const YearlyProjectionPlot({
    super.key,
    required this.years,
    required this.capital,
    required this.interest,
    required this.yLabel,
    required this.labelStyle,
    this.tooltips,
  });

  final List<int> years;
  final List<int> capital;
  final List<int> interest;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;

  /// Hover message per year — same length as [years] when given.
  final List<InlineSpan>? tooltips;

  @override
  State<YearlyProjectionPlot> createState() => _YearlyProjectionPlotState();
}

class _YearlyProjectionPlotState extends State<YearlyProjectionPlot> {
  /// The year under the pointer — hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final tooltips = widget.tooltips;
    final years = widget.years;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _StackedBarsPainter(
              colors: context.colors,
              years: years,
              capital: widget.capital,
              interest: widget.interest,
              yLabel: widget.yLabel,
              labelStyle: widget.labelStyle,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
        // One full-height slot per year, matching the bars' slots: the thing
        // worth hovering is the year, not the bar's few pixels.
        MouseRegion(
          onExit: (_) => setState(() => _hovered = null),
          child: Row(
            children: [
              const SizedBox(width: AppChart.valueGutter),
              for (var i = 0; i < years.length; i++)
                Expanded(
                  child: MouseRegion(
                    key: Key('projectionSlot-$i'),
                    onEnter: (_) => setState(() => _hovered = i),
                    child: Semantics(
                      label: tooltips == null || i >= tooltips.length
                          ? null
                          : tooltips[i].toPlainText(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if ((_hovered, tooltips) case (
          final hovered?,
          final tooltips?,
        ) when hovered < tooltips.length && hovered < years.length)
          LineChartTooltip(
            cardKey: const Key('projectionTooltip'),
            message: tooltips[hovered],
            points: (size) => [for (final bar in _bars(size)) bar.topCenter],
            hovered: hovered,
            pointRadius: 0,
            // Bars, not a line: the card keeps clear of every one.
            joinsNext: (_) => false,
            marks: _bars,
            leftBound: AppChart.valueGutter,
            bottomInset: AppChart.axisHeight,
          ),
      ],
    );
  }

  /// Each year's whole stacked bar in a chart of [size].
  List<Rect> _bars(Size size) => [
    for (var i = 0; i < widget.years.length; i++)
      _barRect(size, widget.capital, widget.interest, i),
  ];
}

/// Where the plot sits in the chart's box: right of the value gutter, above
/// the year axis, a little below the top so the top label isn't clipped.
Rect _projectionPlotRect(Size size) => Rect.fromLTRB(
  AppChart.valueGutter,
  _StackedBarsPainter._topPad,
  size.width,
  size.height - AppChart.axisHeight,
);

/// The bars' scale: from zero to a clean tick past the tallest year. A bar's
/// height is the two API figures laid end to end — geometry for the scale, not
/// a figure the panel prints. Minor units, so no gridline on cents.
ChartScale _projectionScale(List<int> capital, List<int> interest) =>
    ChartScale.of(
      [0, for (var i = 0; i < capital.length; i++) capital[i] + interest[i]],
      intervals: 2,
      minStep: 100,
    );

/// Year [index]'s whole stacked bar, gap included.
Rect _barRect(Size size, List<int> capital, List<int> interest, int index) {
  final plot = _projectionPlotRect(size);
  final scale = _projectionScale(capital, interest);
  final width = math.min(
    _StackedBarsPainter._maxBarWidth,
    plot.width / capital.length * 0.62,
  );
  final center = plot.left + AreaLine.pointX(index, capital.length, plot.width);
  final top = scale.y(capital[index] + interest[index], plot);
  return Rect.fromLTRB(
    center - width / 2,
    interest[index] > 0 ? top - _StackedBarsPainter._stackGap : top,
    center + width / 2,
    plot.bottom,
  );
}

class _StackedBarsPainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _StackedBarsPainter({
    required this.colors,
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

  static const _topPad = 8.0;
  static const _stackGap = AppChart.stackGap;
  static const _maxBarWidth = 44.0;

  /// Gap between the plot's floor and a year label.
  static const _axisLabelGap = 6.0;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: textDirection,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (years.isEmpty || size.width <= AppChart.valueGutter) return;

    final plot = _projectionPlotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;
    final scale = _projectionScale(capital, interest);
    double heightOf(int value) => plot.bottom - scale.y(value, plot);

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in scale.ticks) scale.y(tick, plot)],
      labels: [for (final tick in scale.ticks) yLabel(tick.round())],
      style: labelStyle,
    );

    final width = math.min(_maxBarWidth, plot.width / years.length * 0.62);
    const capRadius = Radius.circular(AppChart.stackRadius);
    const baseRadius = Radius.circular(AppChart.stackRadius);
    final last = years.length - 1;

    for (var index = 0; index < years.length; index++) {
      final center =
          plot.left + AreaLine.pointX(index, years.length, plot.width);
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
          Paint()..color = colors.accent,
        );
      }
      if (interestHeight > 0) {
        final bottom = plot.bottom - capitalHeight - _stackGap;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, bottom - interestHeight, width, interestHeight),
            topLeft: capRadius,
            topRight: capRadius,
            bottomLeft: baseRadius,
            bottomRight: baseRadius,
          ),
          Paint()..color = colors.textTertiary,
        );
      }

      // Every fourth year and the last, dropping a fourth-year label that
      // would crowd the last one.
      final labelled = index == last || (index % 4 == 0 && last - index >= 2);
      if (!labelled) continue;
      final label = _text('${years[index]}');
      label.paint(
        canvas,
        Offset(center - label.width / 2, plot.bottom + _axisLabelGap),
      );
    }
  }

  @override
  bool shouldRepaint(_StackedBarsPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.years, years) ||
      !listEquals(oldDelegate.capital, capital) ||
      !listEquals(oldDelegate.interest, interest) ||
      oldDelegate.labelStyle != labelStyle;
}
