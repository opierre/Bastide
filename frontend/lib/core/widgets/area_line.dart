import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'chart_scale.dart';
import 'chart_tooltip.dart';

/// The savings-evolution area line: an iris 2.5px stroke over a 16% iris fill, hairline
/// gridlines behind it, a dot on the current (last) point, and a month axis beneath
/// (`docs/design/00` §Components → AreaLine).
///
/// Each point sits at the centre of its axis label's slot rather than spreading edge to edge,
/// so a month's dot stands over its own label instead of drifting toward the slot boundary.
/// Hovering a slot rings its point and, when [tooltips] are given, names its figure in a card
/// placed clear of the line — see [placeChartTooltip].
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
    this.color = AppColors.iris,
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
  final Color color;

  /// Whether a series that crosses zero shows where: a dashed zero baseline, the fill above
  /// it in [color] and below it in the expense red. An account balance can dip under zero
  /// and the page must say so (`docs/design/16` §Row 2); a series that stays on one side is
  /// drawn as usual.
  final bool markZero;

  /// The smallest gap between two gridlines, in the units of [values] — see
  /// [ChartScale.of]. A chart of minor units passes 100.
  final num minStep;

  /// Height reserved beneath the plot for the month axis.
  static const axisHeight = 22.0;

  /// Width reserved left of the plot for the value axis, when there is one.
  static const valueGutter = 56.0;

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
    final textTheme = Theme.of(context).textTheme;
    final valueLabel = widget.valueLabel;
    final gutter = valueLabel == null ? 0.0 : AreaLine.valueGutter;
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
            ? math.min(AreaLine.axisHeight, constraints.maxHeight)
            : AreaLine.axisHeight;

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
                        values: values,
                        scale: scale,
                        gridlines: widget.gridlines,
                        color: widget.color,
                        markZero: widget.markZero,
                        hovered: _hovered,
                        gutter: gutter,
                        levelLabels: levels,
                        labelStyle: tabularNumberStyle(textTheme.labelSmall!)
                            .copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
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
                      pointRadius: _AreaLinePainter._dotRadius,
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
                  maxHeight: AreaLine.axisHeight,
                  child: Row(
                    children: [
                      SizedBox(width: gutter),
                      for (final label in labels)
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
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

/// The plot inside a chart of [size]: inset vertically by the dot so an extreme point isn't
/// clipped by the plot's own edge, with the value [gutter] on its left. Horizontally the
/// points already sit half a slot in from either side.
Rect _plotRect(Size size, double gutter) => Rect.fromLTWH(
  gutter,
  _AreaLinePainter._dotRadius,
  size.width - gutter,
  size.height - _AreaLinePainter._dotRadius * 2,
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
  _AreaLinePainter({
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

  static const _stroke = 2.5;
  static const _dotRadius = 5.0;
  static const _fillAlpha = 0.16;
  static const _negativeFillAlpha = 0.10;
  static const _dash = 4.0;
  static const _dashGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size, gutter);
    if (plot.width <= 0) return;

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (final tick in scale.ticks) {
      final y = scale.y(tick, plot);
      canvas.drawLine(Offset(plot.left, y), Offset(size.width, y), grid);
    }

    // Each label beside the gridline it names, bottom to top.
    for (var i = 0; i < levelLabels.length && i < scale.ticks.length; i++) {
      final y = scale.y(scale.ticks[i], plot);
      final label = TextPainter(
        text: TextSpan(text: levelLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      label.paint(
        canvas,
        Offset(plot.left - AppSpacing.sm - label.width, y - label.height / 2),
      );
    }

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
        ..drawPath(area, Paint()..color = color.withValues(alpha: _fillAlpha))
        ..restore()
        ..save()
        ..clipRect(Rect.fromLTRB(plot.left, zeroY, size.width, size.height))
        ..drawPath(
          area,
          Paint()
            ..color = AppColors.negative.withValues(alpha: _negativeFillAlpha),
        )
        ..restore();
      final dash = Paint()
        ..color = AppColors.borderDashed
        ..strokeWidth = 1;
      for (var x = plot.left; x < size.width; x += _dash + _dashGap) {
        canvas.drawLine(
          Offset(x, zeroY),
          Offset(math.min(x + _dash, size.width), zeroY),
          dash,
        );
      }
    } else {
      final area = Path.from(line)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = color.withValues(alpha: _fillAlpha),
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // The current point, and the hovered one, ringed in the card's own surface so the dot
    // reads as sitting on the line rather than as a bead threaded onto it.
    for (final index in {
      values.length - 1,
      if (hovered case final hovered? when hovered < values.length) hovered,
    }) {
      canvas.drawCircle(
        points[index],
        _dotRadius,
        Paint()..color = AppColors.surfaceRaised,
      );
      canvas.drawCircle(
        points[index],
        _dotRadius - _stroke / 2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_AreaLinePainter oldDelegate) =>
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
