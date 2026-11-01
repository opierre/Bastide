import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A chart's hover card: the hovered point's [message], dressed as the app's tooltips are
/// (the theme's [TooltipThemeData]) so every chart's readout looks the same.
///
/// It is only the card. Each chart decides where it goes, so it can keep clear of what
/// the reader is looking at, and shows it instantly rather than after [Tooltip]'s delay.
/// A line chart places it with [LineChartTooltip].
class ChartTooltip extends StatelessWidget {
  const ChartTooltip({super.key, required this.message});

  final InlineSpan message;

  @override
  Widget build(BuildContext context) {
    final theme = TooltipTheme.of(context);
    return DecoratedBox(
      decoration: theme.decoration ?? const BoxDecoration(),
      child: Padding(
        padding: theme.padding ?? EdgeInsets.zero,
        child: Text.rich(TextSpan(children: [message]), style: theme.textStyle),
      ),
    );
  }
}

/// A chart's hover card, laid out over the chart where [placeChartTooltip] puts it:
/// clear of the hovered point, of the line and of any bar, rather than under the pointer.
///
/// Meant as a layer of the chart's own [Stack], sized like the plot's box. [points]
/// gives the line's points for that box's size, from the same geometry the painter
/// draws with, so the card can't drift off the point it names. It is never hit-tested,
/// so it can't steal the pointer from the hover slot beneath it and flicker.
class LineChartTooltip extends StatelessWidget {
  const LineChartTooltip({
    super.key,
    required this.message,
    required this.points,
    required this.hovered,
    required this.pointRadius,
    this.joinsNext,
    this.marks,
    this.leftBound = 0,
    this.bottomInset = 0,
    this.cardKey,
  });

  final InlineSpan message;

  /// The card's own key, for finding where it landed: the widget's [key] spans the box.
  final Key? cardKey;

  /// The line's points in a box of the given size.
  final List<Offset> Function(Size size) points;
  final int hovered;

  /// The hovered dot's radius, which the card keeps clear of too.
  final double pointRadius;

  /// Whether point `i` is joined to point `i + 1`; every point is when null. A chart whose
  /// line breaks at a gap passes it, so the card may sit in the gap.
  final bool Function(int index)? joinsNext;

  /// Each point's bar in a box of the given size, one per point, for a bar chart: the
  /// card keeps clear of them as it does of the line. None when null.
  final List<Rect> Function(Size size)? marks;

  /// Width on the left the card keeps off when the plot has room — the value gutter.
  final double leftBound;

  /// Height at the bottom of the box the card never covers — a month axis drawn inside it.
  final double bottomInset;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomSingleChildLayout(
      delegate: _LineChartTooltipLayout(this),
      child: ChartTooltip(key: cardKey, message: message),
    ),
  );
}

class _LineChartTooltipLayout extends SingleChildLayoutDelegate {
  _LineChartTooltipLayout(this.tooltip);

  final LineChartTooltip tooltip;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final points = tooltip.points(size);
    if (tooltip.hovered >= points.length) return Offset.zero;
    return placeChartTooltip(
      area:
          Offset.zero &
          Size(size.width, math.max(0, size.height - tooltip.bottomInset)),
      points: points,
      hovered: tooltip.hovered,
      tooltip: childSize,
      pointRadius: tooltip.pointRadius,
      joinsNext: tooltip.joinsNext,
      marks: tooltip.marks?.call(size),
      leftBound: tooltip.leftBound,
    );
  }

  // The points come from a closure, which can't be compared; laying out one card again
  // costs nothing.
  @override
  bool shouldRelayout(_LineChartTooltipLayout oldDelegate) => true;
}

/// Where the hover card for point [hovered] goes, as its top-left corner inside [area].
///
/// A tooltip anchored to the pointer covers whatever the reader is looking at, so the card
/// instead looks for room off the line: the spot nearest the hovered point whose box, padded
/// by a margin, touches neither the point (of [pointRadius]) nor any segment of the line.
/// When the line leaves no such room (a sharp zig-zag on a short chart), it settles for
/// keeping clear of the hovered point and the segments either side of it — the part being
/// read. Only a chart too small to hold the card anywhere else falls back to the plot's
/// top-left corner.
///
/// [joinsNext] says which points the line joins; all of them when null — a bar chart, with
/// no line, joins none. [marks] are bars, one per point, kept clear of like the line: all
/// of them, or the hovered one when nothing else leaves room. [leftBound] keeps the card
/// off the value-axis gutter when the plot is wide enough.
Offset placeChartTooltip({
  required Rect area,
  required List<Offset> points,
  required int hovered,
  required Size tooltip,
  required double pointRadius,
  bool Function(int index)? joinsNext,
  List<Rect>? marks,
  double leftBound = 0,
}) {
  final anchor = points[hovered];
  final minX = area.right - tooltip.width >= area.left + leftBound
      ? area.left + leftBound
      : area.left;
  final maxX = math.max(minX, area.right - tooltip.width);
  final minY = area.top;
  final maxY = math.max(minY, area.bottom - tooltip.height);

  bool joins(int i) => joinsNext?.call(i) ?? true;
  final segments = [
    for (var i = 0; i + 1 < points.length; i++)
      if (joins(i)) (points[i], points[i + 1]),
  ];
  final nearby = [
    if (hovered > 0 && joins(hovered - 1)) (points[hovered - 1], anchor),
    if (hovered + 1 < points.length && joins(hovered))
      (anchor, points[hovered + 1]),
  ];

  final hoveredMarks = [
    if (marks != null && hovered < marks.length) marks[hovered],
  ];

  bool clear(Rect box, List<(Offset, Offset)> lines, List<Rect> bars) {
    final padded = box.inflate(_tooltipMargin);
    if (padded.inflate(pointRadius).contains(anchor)) return false;
    if (bars.any(padded.overlaps)) return false;
    return !lines.any((line) => _segmentHitsRect(line.$1, line.$2, padded));
  }

  Offset? nearest(List<(Offset, Offset)> lines, List<Rect> bars) {
    Offset? best;
    var bestDistance = double.infinity;
    // A coarse grid is plenty: the card only has to be clear, not pixel-snug.
    for (var y = minY; y <= maxY + _tooltipStep - 1; y += _tooltipStep) {
      for (var x = minX; x <= maxX + _tooltipStep - 1; x += _tooltipStep) {
        final corner = Offset(math.min(x, maxX), math.min(y, maxY));
        final box = corner & tooltip;
        if (!clear(box, lines, bars)) continue;
        final distance = (box.center - anchor).distanceSquared;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = corner;
        }
      }
    }
    return best;
  }

  return nearest(segments, marks ?? const []) ??
      nearest(nearby, hoveredMarks) ??
      Offset(minX, minY);
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
