import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The savings-evolution area line: an iris 2.5px stroke over a 16% iris fill, hairline
/// gridlines behind it, a dot on the current (last) point, and a month axis beneath
/// (`docs/design/00` §Components → AreaLine).
///
/// Each point sits at the centre of its axis label's slot rather than spreading edge to edge,
/// so a month's dot stands over its own label instead of drifting toward the slot boundary.
/// Hovering a slot rings its point and, when [tooltips] are given, names its figure.
///
/// Deliberately not animated — the spec allows only the spinner and skeleton keyframes, so a
/// chart appears drawn rather than growing in.
class AreaLine extends StatefulWidget {
  const AreaLine({
    super.key,
    required this.values,
    required this.labels,
    this.tooltips,
    this.gridlines = 4,
  });

  /// One value per point, oldest first. Rendered on its own min/max, so a series that never
  /// approaches zero still fills the plot rather than flattening against the top.
  final List<num> values;

  /// Axis label per point — same length as [values].
  final List<String> labels;

  /// Hover message per point — same length as [values] when given. Spans rather than strings,
  /// so the caller styles the figure the way the rest of its card does.
  final List<InlineSpan>? tooltips;

  /// Horizontal hairlines behind the plot.
  final int gridlines;

  /// Height reserved beneath the plot for the month axis.
  static const axisHeight = 22.0;

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
                        hovered: _hovered,
                      ),
                    ),
                  ),
                  // One full-height slice per point, matching the axis slots below: the
                  // dot is a few pixels wide, but the thing worth hovering is the month.
                  MouseRegion(
                    onExit: (_) => setState(() => _hovered = null),
                    child: Row(
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _hovered = i),
                              child: tooltips == null
                                  ? const SizedBox.expand()
                                  : Tooltip(
                                      key: Key('areaLineTooltip-$i'),
                                      richMessage: TextSpan(
                                        children: [tooltips[i]],
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                            ),
                          ),
                      ],
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
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({
    required this.values,
    required this.gridlines,
    required this.hovered,
  });

  final List<num> values;
  final int gridlines;
  final int? hovered;

  static const _stroke = 2.5;
  static const _dotRadius = 5.0;
  static const _fillAlpha = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset vertically by the dot so an extreme point isn't clipped by the plot's own edge.
    // Horizontally the points already sit half a slot in from either side.
    final plot = Rect.fromLTWH(
      0,
      _dotRadius,
      size.width,
      size.height - _dotRadius * 2,
    );

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (var i = 0; i <= gridlines; i++) {
      final y = plot.top + plot.height * (i / gridlines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    // A flat series has no range to normalise against; centre it rather than divide by zero.
    final range = max - min;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          AreaLine.pointX(i, values.length, plot.width),
          range == 0
              ? plot.center.dy
              : plot.bottom - plot.height * ((values[i] - min) / range),
        ),
    ];

    final line = Path()..addPolygon(points, false);
    final area = Path.from(line)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()..color = AppColors.iris.withValues(alpha: _fillAlpha),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.iris
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
        Paint()..color = AppColors.iris,
      );
    }
  }

  @override
  bool shouldRepaint(_AreaLinePainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.gridlines != gridlines ||
      oldDelegate.hovered != hovered;
}
