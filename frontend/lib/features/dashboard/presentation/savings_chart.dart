import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../application/dashboard_controller.dart';

/// What each month put aside, drawn around a zero line in one of two [SavingsChartView]s.
///
/// - **Bars**: one bar per month, income green above zero, expense red below it for a
///   month that spent more than it earned. Each month's saving is its own figure, not a
///   step of a running total, so bars are the default.
/// - **Line**: the same twelve figures joined in order, which reads the direction over
///   many months better. Each point is still dotted in its sign's color, the area between
///   the line and zero is washed in iris as on the Synthèse's « Patrimoine net », and a
///   dashed zero baseline marks where a month turns negative.
///
/// Either way the direction doubles the color, so the sign never rests on hue alone, and
/// the last month — the current one, still moving — is drawn open: a dashed outline bar,
/// or a dashed last segment ending on a hollow dot.
///
/// Hovering a month names its figure in a card placed as on the other charts — see
/// [LineChartTooltip]: the spot nearest the hovered mark that keeps clear of it and of
/// every bar, or of the line, inside the plot.
///
/// Both views share one frame: the [_Scale], the labelled gridlines, the hover slots, the
/// tooltip and the month axis. Only the mark layer differs, so the [average] — a dotted,
/// half-transparent level across the plot — is one step after the marks in
/// [_SavingsChartPainter.paint] and lands in both. Drawn over the marks so a bar can't hide
/// it, and see-through so it can't hide a bar or a dot either.
///
/// Laid out like [AreaLine] (value gutter, slots, month axis) so the card reads like the
/// other charts. Not animated, per the spec's motion rules.
class SavingsChart extends StatefulWidget {
  const SavingsChart({
    super.key,
    required this.values,
    required this.labels,
    required this.valueLabel,
    this.view = SavingsChartView.bars,
    this.tooltips,
    this.average,
  });

  /// Signed minor units per month, oldest first.
  final List<int> values;
  final List<String> labels;
  final String Function(num value) valueLabel;
  final SavingsChartView view;
  final List<InlineSpan>? tooltips;

  /// The window's average saving in minor units, drawn as a dotted level; none when null.
  /// Computed by the domain (`DashboardTrends.averageSavedMinor`), not here.
  final int? average;

  /// The average line's color: the secondary text tone, half-transparent, so it reads as a
  /// reference rather than a series and stays clear of iris (the line view's own stroke)
  /// and of the green/red that carry money. `lineStrong` would match the
  /// dashed zero baseline, so the token is the secondary text tone at 60 %, set as an 8-bit
  /// alpha (153 / 255) so it survives a [Paint] round trip unchanged.
  static Color averageColor(AppColors colors) =>
      colors.textSecondary.withAlpha(153);

  /// The average line's dots: a round cap on a near-zero dash, every [averageDotGap] px.
  static const averageStroke = 1.5;
  static const averageDotGap = 5.0;

  @override
  State<SavingsChart> createState() => _SavingsChartState();
}

class _SavingsChartState extends State<SavingsChart> {
  /// The slot under the pointer — hover ephemera, not chart state.
  int? _hovered;

  void _hover(int? index) => setState(() => _hovered = index);

  @override
  Widget build(BuildContext context) {
    final labelStyle = ChartPaints.labelStyle(context);
    final scale = _Scale.of(widget.values);
    final tooltips = widget.tooltips;

    return Column(
      children: [
        Expanded(child: _plot(scale, labelStyle, tooltips)),
        SizedBox(
          height: AppChart.axisHeight,
          child: Row(
            children: [
              const SizedBox(width: AppChart.valueGutter),
              for (final label in widget.labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The marks, and one full-height hover slot per month over them.
  Widget _plot(
    _Scale scale,
    TextStyle labelStyle,
    List<InlineSpan>? tooltips,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SavingsChartPainter(
            colors: context.colors,
            values: widget.values,
            view: widget.view,
            scale: scale,
            average: widget.average,
            hovered: _hovered,
            levelLabels: scale.levels.map(widget.valueLabel).toList(),
            labelStyle: labelStyle,
          ),
        ),
      ),
      MouseRegion(
        onExit: (_) => _hover(null),
        child: Row(
          children: [
            const SizedBox(width: AppChart.valueGutter),
            for (var i = 0; i < widget.values.length; i++)
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => _hover(i),
                  // The tooltip is drawn, not a [Tooltip], so a screen reader still
                  // needs the month's figure on its slot.
                  child: Semantics(
                    label: tooltips?[i].toPlainText(),
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
      ) when hovered < tooltips.length && hovered < widget.values.length)
        _hoveredTooltip(hovered, tooltips[hovered], scale),
    ],
  );

  /// The hovered month's card, clear of its mark: in the bars view, of every bar (the
  /// line joins no point there); in the line view, of the hovered dot and the line.
  Widget _hoveredTooltip(int hovered, InlineSpan message, _Scale scale) {
    final values = widget.values;
    final bars = widget.view == SavingsChartView.bars;
    return LineChartTooltip(
      cardKey: Key('savingsChartTooltip-$hovered'),
      message: message,
      points: (size) => [
        for (var i = 0; i < values.length; i++)
          _markPoint(values, scale, i, _plotRect(size)),
      ],
      hovered: hovered,
      pointRadius: bars ? 0 : AppChart.dotReach,
      joinsNext: bars ? (_) => false : null,
      marks: bars
          ? (size) => [
              for (var i = 0; i < values.length; i++)
                _barRect(values, scale, i, _plotRect(size)),
            ]
          : null,
      leftBound: AppChart.valueGutter,
    );
  }
}

/// Where the plot sits in the chart's box, right of the value gutter and inset a little
/// top and bottom. Shared by the painter and the tooltip, so a tooltip can't drift off the
/// mark it names.
Rect _plotRect(Size size) => Rect.fromLTWH(
  AppChart.valueGutter,
  4,
  size.width - AppChart.valueGutter,
  size.height - 8,
);

/// Month [index]'s mark: its slot's centre, at its value on the shared scale — the line's
/// dot, or the bar's tip.
Offset _markPoint(List<int> values, _Scale scale, int index, Rect plot) =>
    Offset(
      plot.left + AreaLine.pointX(index, values.length, plot.width),
      scale.y(values[index].toDouble(), plot),
    );

/// Month [index]'s bar: [_SavingsChartPainter.maxBarWidth] at most, or 56 % of its slot,
/// from zero to its tip. Shared by the painter and the tooltip, which keeps clear of it.
Rect _barRect(List<int> values, _Scale scale, int index, Rect plot) {
  final point = _markPoint(values, scale, index, plot);
  final zeroY = scale.y(0, plot);
  final barWidth = math.min(
    _SavingsChartPainter.maxBarWidth,
    plot.width / values.length * 0.56,
  );
  return Rect.fromLTRB(
    point.dx - barWidth / 2,
    math.min(point.dy, zeroY),
    point.dx + barWidth / 2,
    math.max(point.dy, zeroY),
  );
}

/// The plot's value range: zero always inside it, and headroom past the
/// tallest bar either way so none touches the card's edge.
@immutable
class _Scale {
  const _Scale(this.bottom, this.top);

  factory _Scale.of(List<int> values) {
    final highest = values.isEmpty ? 0 : values.reduce(math.max);
    final lowest = values.isEmpty ? 0 : values.reduce(math.min);
    final top = highest > 0 ? highest * _headroom : 0.0;
    final bottom = lowest < 0 ? lowest * _headroom : 0.0;
    // An all-zero series still needs a range to lay out against.
    return top == bottom ? const _Scale(0, 1) : _Scale(bottom, top);
  }

  static const _headroom = 1.15;

  final double bottom;
  final double top;

  /// The gridlines' values, bottom to top: zero and each side's end, or zero,
  /// a midpoint and the end when every month falls on one side of it.
  List<double> get levels {
    if (bottom < 0 && top > 0) return [bottom, 0, top];
    if (bottom < 0) return [bottom, bottom / 2, 0];
    return [0, top / 2, top];
  }

  double y(double value, Rect plot) =>
      plot.bottom - plot.height * ((value - bottom) / (top - bottom));

  @override
  bool operator ==(Object other) =>
      other is _Scale && other.bottom == bottom && other.top == top;

  @override
  int get hashCode => Object.hash(bottom, top);
}

class _SavingsChartPainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _SavingsChartPainter({
    required this.colors,
    required this.values,
    required this.view,
    required this.scale,
    required this.average,
    required this.hovered,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<int> values;
  final SavingsChartView view;
  final _Scale scale;
  final int? average;
  final int? hovered;
  final List<String> levelLabels;
  final TextStyle labelStyle;

  static const maxBarWidth = 22.0;
  static const _tipRadius = 5.0;
  static const _baseRadius = 2.0;
  static const _barAlpha = 0.7;
  static const _hoverAlpha = 0.9;
  static const _openFillAlpha = 0.08;

  /// The open bar's dashed outline.
  static const _openOutline = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;

    _paintGrid(canvas, size, plot);
    if (values.isEmpty) return;
    switch (view) {
      case SavingsChartView.bars:
        _paintBars(canvas, plot);
      case SavingsChartView.line:
        _paintLine(canvas, size, plot);
    }
    // Overlays shared by both views paint after the marks, on the same scale.
    _paintAverage(canvas, size, plot);
  }

  /// The [average] as a dotted level across the plot. The scale always holds it: a mean
  /// lies between the lowest and the highest month.
  void _paintAverage(Canvas canvas, Size size, Rect plot) {
    final average = this.average;
    if (average == null) return;
    final y = scale.y(average.toDouble(), plot);
    paintDottedLine(
      canvas,
      Offset(plot.left, y),
      Offset(size.width, y),
      SavingsChart.averageColor(colors),
    );
  }

  /// The labelled gridlines both views stand on.
  void _paintGrid(Canvas canvas, Size size, Rect plot) => ChartPaints.grid(
    colors,
    canvas,
    size,
    plot,
    [for (final level in scale.levels) scale.y(level, plot)],
    labels: levelLabels,
    style: labelStyle,
  );

  /// Month [index]'s position: its slot's centre, at its value on the shared scale.
  Offset _point(int index, Rect plot) => _markPoint(values, scale, index, plot);

  void _paintBars(Canvas canvas, Rect plot) {
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == 0) continue;
      final up = value > 0;
      // The rounded end is the tip, away from zero, whichever way the bar runs.
      const tip = Radius.circular(_tipRadius);
      const base = Radius.circular(_baseRadius);
      final rect = RRect.fromRectAndCorners(
        _barRect(values, scale, i, plot),
        topLeft: up ? tip : base,
        topRight: up ? tip : base,
        bottomLeft: up ? base : tip,
        bottomRight: up ? base : tip,
      );
      final color = up ? colors.positive : colors.negative;
      if (i == values.length - 1) {
        canvas.drawRRect(
          rect,
          Paint()..color = color.withValues(alpha: _openFillAlpha),
        );
        canvas.drawPath(
          ChartPaints.dashed(Path()..addRRect(rect)),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = _openOutline,
        );
      } else {
        final alpha = hovered == i ? _hoverAlpha : _barAlpha;
        canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: alpha));
      }
    }
  }

  void _paintLine(Canvas canvas, Size size, Rect plot) {
    final points = [for (var i = 0; i < values.length; i++) _point(i, plot)];

    // The zero baseline, dashed as on [AreaLine]'s `markZero`, so a dip below it reads
    // as a month that spent more than it earned. Drawn whenever zero is not the plot's
    // own floor, where the bottom gridline already marks it.
    final zeroY = scale.y(0, plot);
    if (scale.bottom < 0) {
      ChartPaints.baseline(
        colors,
        canvas,
        Offset(plot.left, zeroY),
        Offset(size.width, zeroY),
      );
    }

    // The area between the line and zero, in the shared curve fill: closed on the zero
    // line rather than the plot's floor, so a saving fills up to its point and a shortfall
    // down to its own, the same way. Under the line, so the stroke and dots stay crisp
    // over it.
    if (points.length > 1) {
      canvas.drawPath(
        Path()
          ..addPolygon(points, false)
          ..lineTo(points.last.dx, zeroY)
          ..lineTo(points.first.dx, zeroY)
          ..close(),
        ChartPaints.area(colors.accent),
      );
    }

    // Settled months as one solid path; the segment into the open month dashed, as the
    // open bar is outlined.
    final settled = points.length > 1
        ? points.sublist(0, points.length - 1)
        : points;
    canvas.drawPath(
      Path()..addPolygon(settled, false),
      ChartPaints.stroke(colors.accent),
    );
    if (points.length > 1) {
      canvas.drawPath(
        ChartPaints.dashed(
          Path()
            ..moveTo(points[points.length - 2].dx, points[points.length - 2].dy)
            ..lineTo(points.last.dx, points.last.dy),
        ),
        ChartPaints.stroke(colors.accent)..strokeCap = StrokeCap.butt,
      );
    }

    // A dot per month in its sign's color — the one place a curve's dots don't take the
    // line's hue, since the sign is what each month says. The hovered month's dot is the
    // full-size one; the open month's is full-size and hollow.
    for (var i = 0; i < points.length; i++) {
      final color = values[i] < 0 ? colors.negative : colors.positive;
      if (i == points.length - 1) {
        ChartPaints.hollowDot(
          colors,
          canvas,
          points[i],
          AppChart.currentDotRadius,
          color,
        );
      } else {
        ChartPaints.dot(
          colors,
          canvas,
          points[i],
          hovered == i ? AppChart.currentDotRadius : AppChart.pointDotRadius,
          color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SavingsChartPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.view != view ||
      oldDelegate.scale != scale ||
      oldDelegate.average != average ||
      oldDelegate.hovered != hovered ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}

/// A dotted horizontal run from [from] to [to] in [color]: the chart's
/// average line, and the legend swatch that names it.
void paintDottedLine(Canvas canvas, Offset from, Offset to, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = SavingsChart.averageStroke
    ..strokeCap = StrokeCap.round;
  for (var x = from.dx; x <= to.dx; x += SavingsChart.averageDotGap) {
    canvas.drawLine(Offset(x, from.dy), Offset(x + 0.01, from.dy), paint);
  }
}

/// The average line's legend mark: a short dotted run, drawn exactly as the line is, to
/// sit beside the caption that names it.
class SavingsAverageSwatch extends StatelessWidget {
  const SavingsAverageSwatch({super.key});

  static const width = 16.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(width, SavingsChart.averageStroke * 2),
    painter: _SwatchPainter(SavingsChart.averageColor(context.colors)),
  );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final inset = SavingsChart.averageStroke / 2;
    paintDottedLine(
      canvas,
      Offset(inset, y),
      Offset(size.width - inset, y),
      color,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) => oldDelegate.color != color;
}
