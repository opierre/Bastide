import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'chart_tooltip.dart';

/// The savings-evolution area line: an iris 2.5px stroke over a 16% iris fill, hairline
/// gridlines behind it, a dot on the current (last) point, and a month axis beneath
/// (`docs/design/00` §Components → AreaLine).
///
/// Each point sits at the centre of its axis label's slot rather than spreading edge to edge,
/// so a month's dot stands over its own label instead of drifting toward the slot boundary.
/// Hovering a slot rings its point and, when [tooltips] are given, names its figure in a card
/// placed clear of the line — see [placeAreaLineTooltip].
/// Given a [valueLabel], the min / mid / max gridlines are labelled in a gutter on the left,
/// as on the Synthèse's « Patrimoine net » chart.
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
  });

  /// One value per point, oldest first. Rendered on its own min/max, so a series that never
  /// approaches zero still fills the plot rather than flattening against the top.
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
    // Bottom to top: the series' min, mid and max, where the painter draws them — or the one
    // level a flat series sits on.
    final levels = values.length < 2 || valueLabel == null
        ? const <String>[]
        : _levels(values).map(valueLabel).toList();

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
                    // Laid out over the plot but never hit-tested, so the card can't steal
                    // the pointer from the slot beneath it and flicker.
                    IgnorePointer(
                      child: CustomSingleChildLayout(
                        delegate: _TooltipPlacement(
                          values: values,
                          gutter: gutter,
                          hovered: hovered,
                        ),
                        child: ChartTooltip(
                          key: const Key('areaLineTooltip'),
                          message: tooltips[hovered],
                        ),
                      ),
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

/// Lays the hover card out where [placeAreaLineTooltip] says, from the same geometry the
/// painter draws with.
class _TooltipPlacement extends SingleChildLayoutDelegate {
  _TooltipPlacement({
    required this.values,
    required this.gutter,
    required this.hovered,
  });

  final List<num> values;
  final double gutter;
  final int hovered;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => placeAreaLineTooltip(
    area: Offset.zero & size,
    points: _points(values, _plotRect(size, gutter)),
    hovered: hovered,
    tooltip: childSize,
    leftBound: gutter,
  );

  @override
  bool shouldRelayout(_TooltipPlacement oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.gutter != gutter ||
      oldDelegate.hovered != hovered;
}

/// Where the hover card for point [hovered] goes, as its top-left corner inside [area].
///
/// A tooltip anchored to the pointer covers whatever the reader is looking at, so the card
/// instead looks for room off the line: the spot nearest the hovered point whose box, padded
/// by a margin, touches neither the point nor any segment of the line. When the line leaves
/// no such room (a sharp zig-zag on a short chart), it settles for keeping clear of the
/// hovered point and the two segments either side of it — the part being read. Only a chart
/// too small to hold the card anywhere else falls back to the plot's top-left corner.
///
/// [leftBound] keeps the card off the value-axis gutter when the plot is wide enough.
@visibleForTesting
Offset placeAreaLineTooltip({
  required Rect area,
  required List<Offset> points,
  required int hovered,
  required Size tooltip,
  double leftBound = 0,
}) {
  final anchor = points[hovered];
  final minX = area.right - tooltip.width >= area.left + leftBound
      ? area.left + leftBound
      : area.left;
  final maxX = math.max(minX, area.right - tooltip.width);
  final minY = area.top;
  final maxY = math.max(minY, area.bottom - tooltip.height);

  final segments = [
    for (var i = 0; i + 1 < points.length; i++) (points[i], points[i + 1]),
  ];
  final nearby = [
    if (hovered > 0) segments[hovered - 1],
    if (hovered < segments.length) segments[hovered],
  ];

  bool clear(Rect box, List<(Offset, Offset)> lines) {
    final padded = box.inflate(_tooltipMargin);
    if (padded.inflate(_AreaLinePainter._dotRadius).contains(anchor)) {
      return false;
    }
    return !lines.any((line) => _segmentHitsRect(line.$1, line.$2, padded));
  }

  Offset? nearest(List<(Offset, Offset)> lines) {
    Offset? best;
    var bestDistance = double.infinity;
    // A coarse grid is plenty: the card only has to be clear, not pixel-snug.
    for (var y = minY; y <= maxY + _tooltipStep - 1; y += _tooltipStep) {
      for (var x = minX; x <= maxX + _tooltipStep - 1; x += _tooltipStep) {
        final corner = Offset(math.min(x, maxX), math.min(y, maxY));
        final box = corner & tooltip;
        if (!clear(box, lines)) continue;
        final distance = (box.center - anchor).distanceSquared;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = corner;
        }
      }
    }
    return best;
  }

  return nearest(segments) ?? nearest(nearby) ?? Offset(minX, minY);
}

/// The clear space kept between the hover card and the line or its point.
const _tooltipMargin = AppSpacing.sm;

/// The grid the hover card's position is searched on.
const _tooltipStep = AppSpacing.xs;

/// Whether the segment [a]–[b] crosses or lies inside [rect] (Liang–Barsky clipping).
bool _segmentHitsRect(Offset a, Offset b, Rect rect) {
  final d = b - a;
  var t0 = 0.0;
  var t1 = 1.0;
  for (final (p, q) in [
    (-d.dx, a.dx - rect.left),
    (d.dx, rect.right - a.dx),
    (-d.dy, a.dy - rect.top),
    (d.dy, rect.bottom - a.dy),
  ]) {
    if (p == 0) {
      if (q < 0) return false;
      continue;
    }
    final t = q / p;
    if (p < 0) {
      if (t > t1) return false;
      if (t > t0) t0 = t;
    } else {
      if (t < t0) return false;
      if (t < t1) t1 = t;
    }
  }
  return true;
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

/// Where each value is drawn in [plot], on the series' own min / max. A flat series has no
/// range to normalise against, so it sits on the plot's centre line rather than divide by zero.
List<Offset> _points(List<num> values, Rect plot) {
  if (values.isEmpty) return const [];
  final min = values.reduce((a, b) => a < b ? a : b).toDouble();
  final max = values.reduce((a, b) => a > b ? a : b).toDouble();
  final range = max - min;
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        plot.left + AreaLine.pointX(i, values.length, plot.width),
        range == 0
            ? plot.center.dy
            : plot.bottom - plot.height * ((values[i] - min) / range),
      ),
  ];
}

/// The values the min / mid / max gridlines stand for, bottom to top — just one for a flat
/// series, whose line is centred rather than spread across the plot.
List<num> _levels(List<num> values) {
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  return min == max ? [min] : [min, (min + max) / 2, max];
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({
    required this.values,
    required this.gridlines,
    required this.color,
    required this.markZero,
    required this.hovered,
    required this.gutter,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<num> values;
  final int gridlines;
  final Color color;
  final bool markZero;
  final int? hovered;

  /// Left inset of the plot, holding the value axis; zero without one.
  final double gutter;

  /// The value axis' labels, bottom to top — see [_levels]. Empty without an axis.
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
    for (var i = 0; i <= gridlines; i++) {
      final y = plot.top + plot.height * (i / gridlines);
      canvas.drawLine(Offset(plot.left, y), Offset(size.width, y), grid);
    }

    // Min at the bottom gridline, max at the top, mid halfway — the one level of a flat
    // series sits at the centre, where its line is drawn.
    for (var i = 0; i < levelLabels.length; i++) {
      final y = levelLabels.length == 1
          ? plot.center.dy
          : plot.bottom - plot.height * (i / (levelLabels.length - 1));
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

    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = max - min;
    final points = _points(values, plot);

    final line = Path()..addPolygon(points, false);
    final crossesZero = markZero && range > 0 && min < 0 && max > 0;
    if (crossesZero) {
      // The fill closes on the zero line rather than the plot's floor, then is split there:
      // what lies above it is balance, what lies below it is overdraft.
      final zeroY = plot.bottom - plot.height * (-min / range);
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
      oldDelegate.gridlines != gridlines ||
      oldDelegate.color != color ||
      oldDelegate.markZero != markZero ||
      oldDelegate.hovered != hovered ||
      oldDelegate.gutter != gutter ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
