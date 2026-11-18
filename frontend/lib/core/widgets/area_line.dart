import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chart_scale.dart';
import 'chart_style.dart';
import 'chart_tooltip.dart';

/// The area line, drawn in the shared curve style ([AppChart], [ChartPaints]): a 2.5px
/// stroke over a 16% fill of its [color], hairline gridlines behind it, a small dot on each
/// point (up to [AppChart.dotCeiling]) and a larger one on the current (last) point, and a
/// month axis beneath (`docs/design/00` §Components → AreaLine).
///
/// Each point sits at the centre of its axis label's slot rather than spreading edge to edge,
/// so a month's dot stands over its own label instead of drifting toward the slot boundary.
/// Hovering a slot enlarges its point and, when [tooltips] are given, names its figure in a
/// card placed clear of the line — see [placeChartTooltip].
/// Given a [valueLabel], every gridline is labelled in a gutter on the left, as on the
/// Synthèse's « Patrimoine net » chart. The value range is padded past the series' min and
/// max to clean tick values (see [ChartScale]), so the extremes sit inside the plot.
///
/// Deliberately not animated — the spec allows only the spinner and skeleton keyframes, so a
/// chart appears drawn rather than growing in.
class AreaLine extends StatefulWidget {
  const AreaLine({
    super.key,
    required this.values,
    required this.labels,
    this.tooltips,
    this.valueLabel,
    this.gridlines = 4,
    this.color,
    this.markZero = false,
    this.minStep = 1,
  });

  /// One value per point, oldest first. Rendered on its own padded range rather than from
  /// zero, so a series that never approaches zero still fills the plot rather than
  /// flattening against the top.
  final List<num> values;

  /// Axis label per point — same length as [values].
  final List<String> labels;

  /// Hover message per point — same length as [values] when given. Spans rather than strings,
  /// so the caller styles the figure the way the rest of its card does.
  final List<InlineSpan>? tooltips;

  /// Formats a value for the left axis; without it the chart has no value axis.
  final String Function(num value)? valueLabel;

  /// Horizontal hairlines behind the plot.
  final int gridlines;

  /// The line, its fill and its dots. Iris on the dashboard's savings chart, where the
  /// figure is the app's hero metric; an account's balance takes the leading chart hue
  /// instead, since iris is the accent role and never data (`docs/design/16` §Row 2).
  /// `null` draws the series in `accent`.
  final Color? color;

  /// Whether a series that crosses zero shows where: a dashed zero baseline, the fill above
  /// it in [color] and below it in the expense red. An account balance can dip under zero
  /// and the page must say so (`docs/design/16` §Row 2); a series that stays on one side is
  /// drawn as usual.
  final bool markZero;

  /// The smallest gap between two gridlines, in the units of [values] — see
  /// [ChartScale.of]. A chart of minor units passes 100.
  final num minStep;

  /// The horizontal centre of point [index] of [count] across [width]: the middle of its
  /// label's slot. Shared by the painter and the axis so the two can never disagree.
  static double pointX(int index, int count, double width) =>
      width * (index + 0.5) / count;

  @override
  State<AreaLine> createState() => _AreaLineState();
}

class _AreaLineState extends State<AreaLine> {
  /// The slot under the pointer — hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final labels = widget.labels;
    final tooltips = widget.tooltips;
    final labelStyle = ChartPaints.labelStyle(context);
    final valueLabel = widget.valueLabel;
    final gutter = valueLabel == null ? 0.0 : AppChart.valueGutter;
    final scale = ChartScale.of(
      values,
      intervals: widget.gridlines,
      minStep: widget.minStep,
    );
    // Bottom to top: one label per gridline, where the painter draws them.
    final levels = values.length < 2 || valueLabel == null
        ? const <String>[]
        : scale.ticks.map(valueLabel).toList();

    // The axis is a fixed band under a flexible plot, so a card shorter than the band has
    // nothing left to give it and the column overflows its own box. On a short window the
    // band gives way instead — a clipped axis is a worse chart, an overflow is a broken one.
    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = constraints.hasBoundedHeight
            ? math.min(AppChart.axisHeight, constraints.maxHeight)
            : AppChart.axisHeight;

        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _AreaLinePainter(
                        colors: context.colors,
                        values: values,
                        scale: scale,
                        gridlines: widget.gridlines,
                        color: widget.color ?? context.colors.accent,
                        markZero: widget.markZero,
                        hovered: _hovered,
                        gutter: gutter,
                        levelLabels: levels,
                        labelStyle: labelStyle,
                      ),
                    ),
                  ),
                  // One full-height slice per point, matching the axis slots below: the
                  // dot is a few pixels wide, but the thing worth hovering is the month.
                  MouseRegion(
                    onExit: (_) => setState(() => _hovered = null),
                    child: Row(
                      children: [
                        SizedBox(width: gutter),
                        Expanded(child: _slots(values.length, tooltips)),
                      ],
                    ),
                  ),
                  if ((_hovered, tooltips) case (
                    final hovered?,
                    final tooltips?,
                  ) when hovered < tooltips.length && hovered < values.length)
                    LineChartTooltip(
                      cardKey: const Key('areaLineTooltip'),
                      message: tooltips[hovered],
                      points: (size) =>
                          _points(values, _plotRect(size, gutter), scale),
                      hovered: hovered,
                      pointRadius: AppChart.dotReach,
                      leftBound: gutter,
                    ),
                ],
              ),
            ),
            SizedBox(
              height: axis,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: AppChart.axisHeight,
                  child: Row(
                    children: [
                      SizedBox(width: gutter),
                      for (final label in labels)
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
              ),
            ),
          ],
        );
      },
    );
  }

  /// One full-height slice per point, matching the axis slots below: the dot is a few pixels
  /// wide, but the thing worth hovering is the month. Each slice carries its message as a
  /// semantics label, since the card itself only exists while a pointer hovers.
  Widget _slots(int count, List<InlineSpan>? tooltips) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Expanded(
          child: MouseRegion(
            key: Key('areaLineSlot-$i'),
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
  );
}

/// The plot inside a chart of [size]: inset vertically by the current dot so an extreme
/// point isn't clipped by the plot's own edge, with the value [gutter] on its left.
/// Horizontally the points already sit half a slot in from either side.
Rect _plotRect(Size size, double gutter) => Rect.fromLTWH(
  gutter,
  AppChart.dotReach,
  size.width - gutter,
  size.height - AppChart.dotReach * 2,
);

/// Where each value is drawn in [plot], on the padded [scale] of the series.
List<Offset> _points(List<num> values, Rect plot, ChartScale scale) => [
  for (var i = 0; i < values.length; i++)
    Offset(
      plot.left + AreaLine.pointX(i, values.length, plot.width),
      scale.y(values[i], plot),
    ),
];

class _AreaLinePainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _AreaLinePainter({
    required this.colors,
    required this.values,
    required this.scale,
    required this.gridlines,
    required this.color,
    required this.markZero,
    required this.hovered,
    required this.gutter,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<num> values;
  final ChartScale scale;
  final int gridlines;

  final Color color;
  final bool markZero;
  final int? hovered;

  /// Left inset of the plot, holding the value axis; zero without one.
  final double gutter;

  /// The value axis' labels, one per [ChartScale.ticks], bottom to top. Empty without
  /// an axis.
  final List<String> levelLabels;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size, gutter);
    if (plot.width <= 0) return;

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in scale.ticks) scale.y(tick, plot)],
      labels: levelLabels,
      style: labelStyle,
    );

    if (values.length < 2) return;

    final min = values.fold<num>(values.first, math.min);
    final max = values.fold<num>(values.first, math.max);
    final points = _points(values, plot, scale);

    final line = Path()..addPolygon(points, false);
    final crossesZero = markZero && min < 0 && max > 0;
    if (crossesZero) {
      // The fill closes on the zero line rather than the plot's floor, then is split there:
      // what lies above it is balance, what lies below it is overdraft.
      final zeroY = scale.y(0, plot);
      final area = Path.from(line)
        ..lineTo(points.last.dx, zeroY)
        ..lineTo(points.first.dx, zeroY)
        ..close();
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(plot.left, 0, size.width, zeroY))
        ..drawPath(area, ChartPaints.area(color))
        ..restore()
        ..save()
        ..clipRect(Rect.fromLTRB(plot.left, zeroY, size.width, size.height))
        ..drawPath(area, ChartPaints.negativeArea(colors))
        ..restore();
      ChartPaints.zeroLine(
        colors,
        canvas,
        Offset(plot.left, zeroY),
        Offset(size.width, zeroY),
      );
    } else {
      final area = Path.from(line)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(area, ChartPaints.area(color));
    }
    canvas.drawPath(line, ChartPaints.stroke(color));

    // A small dot on every point while they stay few; the current point and the hovered
    // one at full size.
    final large = {
      values.length - 1,
      if (hovered case final hovered? when hovered < values.length) hovered,
    };
    if (points.length <= AppChart.dotCeiling) {
      for (var i = 0; i < points.length; i++) {
        if (large.contains(i)) continue;
        ChartPaints.dot(
          colors,
          canvas,
          points[i],
          AppChart.pointDotRadius,
          color,
        );
      }
    }
    for (final index in large) {
      ChartPaints.dot(
        colors,
        canvas,
        points[index],
        AppChart.currentDotRadius,
        color,
      );
    }
  }

  @override
  bool shouldRepaint(_AreaLinePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.scale != scale ||
      oldDelegate.gridlines != gridlines ||
      oldDelegate.color != color ||
      oldDelegate.markZero != markZero ||
      oldDelegate.hovered != hovered ||
      oldDelegate.gutter != gutter ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
