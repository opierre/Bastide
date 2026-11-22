import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
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

/// « Capital restant dû jusqu’au dernier remboursement » (`12-credits.md` §3):
/// the combined outstanding principal of all active loans, month by month to
/// the last instalment, with today and each loan's end annotated. A section,
/// not a card: the heading, then the plot taking the height it is given.
///
/// One series, so no legend (`00` §9). The series is the API's
/// (`outstanding_series`); no schedule is summed here.
class TrajectorySection extends StatelessWidget {
  const TrajectorySection({
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
              mortgageLongMonthFormat(locale).format(point.month),
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
          label: switch (state.kindOf(end.mortgageId)) {
            final kind? => l10n.mortgagesChartLoanEnd(
              mortgageKindLabel(l10n, kind).toLowerCase(),
            ),
            null => end.label,
          },
        ),
    ];

    return Column(
      key: const Key('trajectorySection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.smPlus),
          child: Text(
            l10n.mortgagesChartTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
        ),
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
            labelStyle: ChartPaints.labelStyle(context),
            // The month and what is still owed then: a neutral figure, like
            // every amount on this panel.
            tooltips: [
              for (final point in series)
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${_capitalize(mortgageLongMonthFormat(locale).format(point.month))}\n',
                      style: tabularNumberStyle(textTheme.labelSmall!),
                    ),
                    TextSpan(
                      text: formatAmount(
                        amountMinor: point.outstandingMinor,
                        currency: summary.currency,
                        locale: locale,
                      ),
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

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// The plot itself, in the shared curve style ([AppChart]): labelled y
/// gridlines on clean ticks from zero (see [ChartScale]), the `accent` area line,
/// five-yearly x labels and the dashed annotations. Not animated — charts
/// appear drawn.
///
/// Its own on purpose (`12-credits.md` §3): a monthly series runs to the last
/// instalment, far past [AppChart.dotCeiling], so only the annotated months
/// carry a dot — today's full size, each loan end small — and the x axis names
/// every fifth year rather than every month. A band above the plot holds the
/// annotation labels.
///
/// Hovering anywhere over the plot rings the nearest month and names what is
/// still owed then, in the card every chart uses (see [LineChartTooltip]).
class TrajectoryPlot extends StatefulWidget {
  const TrajectoryPlot({
    super.key,
    required this.months,
    required this.values,
    required this.annotations,
    required this.yLabel,
    required this.labelStyle,
    this.tooltips,
  });

  final List<DateTime> months;
  final List<int> values;
  final List<TrajectoryAnnotation> annotations;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;

  /// Hover message per month — same length as [months] when given.
  final List<InlineSpan>? tooltips;

  /// Today's dashed vertical, a step brighter than the end markers.
  static Color todayColor(AppColors colors) => colors.textTertiary;

  /// A loan end's dashed vertical.
  static Color endColor(AppColors colors) => colors.lineStrong;

  /// A loan end's label; today's is `text` (`12-credits.md` §3).
  static Color endLabelColor(AppColors colors) => colors.textTertiary;

  @override
  State<TrajectoryPlot> createState() => _TrajectoryPlotState();
}

class _TrajectoryPlotState extends State<TrajectoryPlot> {
  /// The month nearest the pointer — hover ephemera, not chart state.
  int? _hovered;

  void _hover(Offset local, Size size) {
    final months = widget.months;
    if (months.length < 2) return;
    final plot = _trajectoryPlotRect(size);
    final span = math.max(1, _monthOffset(months, months.last));
    final offset = ((local.dx - plot.left) / plot.width * span).round().clamp(
      0,
      span,
    );
    // The series is monthly and gapless, but find the month rather than trust
    // that its index is its offset.
    var nearest = 0;
    var best = 1 << 30;
    for (var i = 0; i < months.length; i++) {
      final distance = (_monthOffset(months, months[i]) - offset).abs();
      if (distance < best) {
        best = distance;
        nearest = i;
      }
    }
    if (nearest != _hovered) setState(() => _hovered = nearest);
  }

  @override
  Widget build(BuildContext context) {
    final tooltips = widget.tooltips;
    // No LayoutBuilder: the credits panel lays this card out by its intrinsic
    // size, which a LayoutBuilder cannot report. The hover reads the box's
    // size when the pointer moves instead.
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrajectoryPainter(
              colors: context.colors,
              months: widget.months,
              values: widget.values,
              annotations: widget.annotations,
              yLabel: widget.yLabel,
              labelStyle: ChartPaints.painted(context, widget.labelStyle),
              textDirection: Directionality.of(context),
              hovered: _hovered,
            ),
          ),
        ),
        if (tooltips != null)
          MouseRegion(
            key: const Key('trajectoryHover'),
            onHover: (event) {
              final size = context.size;
              if (size != null) _hover(event.localPosition, size);
            },
            onExit: (_) => setState(() => _hovered = null),
            child: const SizedBox.expand(),
          ),
        if ((_hovered, tooltips) case (
          final hovered?,
          final tooltips?,
        ) when hovered < tooltips.length && hovered < widget.values.length)
          LineChartTooltip(
            cardKey: const Key('trajectoryTooltip'),
            message: tooltips[hovered],
            points: (size) =>
                _trajectoryPoints(size, widget.months, widget.values),
            hovered: hovered,
            pointRadius: AppChart.dotReach,
            leftBound: AppChart.valueGutter,
            bottomInset: AppChart.axisHeight,
          ),
      ],
    );
  }
}

/// Months from the series' first to [month].
int _monthOffset(List<DateTime> months, DateTime month) =>
    (month.year - months.first.year) * 12 + month.month - months.first.month;

/// Where the plot sits in the chart's box: right of the value gutter, under
/// the annotation band, above the year axis, inset on the right by the dot.
/// Shared by the painter, the hover and the card.
Rect _trajectoryPlotRect(Size size) => Rect.fromLTRB(
  AppChart.valueGutter,
  _TrajectoryPainter._topBand,
  size.width - AppChart.dotReach,
  size.height - AppChart.axisHeight,
);

/// The series' scale: from zero, the debt's floor, to a clean tick past the
/// peak — « 0 · 100 k€ · 200 k€ · 300 k€ » for a 255 000 € peak. Minor units,
/// so no gridline on cents.
ChartScale _trajectoryScale(List<int> values) =>
    ChartScale.of([0, ...values], intervals: 3, minStep: 100);

/// Each month's point in a chart of [size].
List<Offset> _trajectoryPoints(
  Size size,
  List<DateTime> months,
  List<int> values,
) {
  if (months.isEmpty) return const [];
  final plot = _trajectoryPlotRect(size);
  final scale = _trajectoryScale(values);
  final span = math.max(1, _monthOffset(months, months.last));
  return [
    for (var i = 0; i < months.length; i++)
      Offset(
        plot.left + plot.width * (_monthOffset(months, months[i]) / span),
        scale.y(values[i], plot),
      ),
  ];
}

class _TrajectoryPainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _TrajectoryPainter({
    required this.colors,
    required this.months,
    required this.values,
    required this.annotations,
    required this.yLabel,
    required this.labelStyle,
    required this.textDirection,
    required this.hovered,
  });

  final List<DateTime> months;
  final List<int> values;
  final List<TrajectoryAnnotation> annotations;
  final String Function(int minor) yLabel;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final int? hovered;

  /// The band above the plot that holds the annotation labels.
  static const _topBand = 20.0;

  /// Gap between the plot's floor and a year label.
  static const _axisLabelGap = 6.0;

  /// Gap between an annotation's vertical and its label.
  static const _annotationLabelGap = 6.0;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (months.length < 2 || size.width <= AppChart.valueGutter) return;

    final plot = _trajectoryPlotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;
    final scale = _trajectoryScale(values);
    final span = math.max(1, _monthOffset(months, months.last));
    double xOf(DateTime month) =>
        plot.left + plot.width * (_monthOffset(months, month) / span);

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in scale.ticks) scale.y(tick, plot)],
      labels: [for (final tick in scale.ticks) yLabel(tick.round())],
      style: labelStyle,
    );

    for (var year = months.first.year; year <= months.last.year; year++) {
      if (year % 5 != 0) continue;
      final month = DateTime(year);
      if (_monthOffset(months, month) < 0) continue;
      final label = _text('$year', labelStyle);
      label.paint(
        canvas,
        Offset(xOf(month) - label.width / 2, plot.bottom + _axisLabelGap),
      );
    }

    final points = _trajectoryPoints(size, months, values);
    final line = Path()..addPolygon(points, false);
    final area = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(area, ChartPaints.area(colors.accent));
    canvas.drawPath(line, ChartPaints.stroke(colors.accent));

    for (final annotation in annotations) {
      final index = months.indexWhere(
        (month) =>
            month.year == annotation.month.year &&
            month.month == annotation.month.month,
      );
      if (index < 0) continue;
      final point = points[index];
      final color = annotation.isToday
          ? TrajectoryPlot.todayColor(colors)
          : TrajectoryPlot.endColor(colors);

      ChartPaints.baseline(
        colors,
        canvas,
        Offset(point.dx, plot.top),
        Offset(point.dx, plot.bottom),
        color: color,
      );
      // Today is this chart's current point; a loan end is an ordinary one.
      ChartPaints.dot(
        colors,
        canvas,
        point,
        annotation.isToday
            ? AppChart.currentDotRadius
            : AppChart.pointDotRadius,
        colors.accent,
      );

      final label = _text(
        annotation.label,
        labelStyle.copyWith(
          color: annotation.isToday
              ? colors.text
              : TrajectoryPlot.endLabelColor(colors),
        ),
      );
      // Set right of its line, or left of it when that would run off the plot.
      final x = point.dx + _annotationLabelGap + label.width > plot.right
          ? point.dx - _annotationLabelGap - label.width
          : point.dx + _annotationLabelGap;
      // Today's label sits in the band above the plot; an end's a row lower,
      // inside it, so the two never collide when the months are close.
      final y = annotation.isToday
          ? plot.top - label.height
          : plot.top + _annotationLabelGap;
      label.paint(canvas, Offset(x, y));
    }

    if (hovered case final hovered? when hovered < points.length) {
      ChartPaints.dot(
        colors,
        canvas,
        points[hovered],
        AppChart.currentDotRadius,
        colors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_TrajectoryPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.months, months) ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.annotations, annotations) ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.hovered != hovered;
}
