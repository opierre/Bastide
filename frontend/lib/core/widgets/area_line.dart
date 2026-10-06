import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The savings-evolution area line: an iris 2.5px stroke over a 16% iris fill, hairline
/// gridlines behind it, a dot on the current (last) point, and a month axis beneath
/// (`docs/design/00` §Components → AreaLine).
///
/// Deliberately not animated — the spec allows only the spinner and skeleton keyframes, so a
/// chart appears drawn rather than growing in.
class AreaLine extends StatelessWidget {
  const AreaLine({
    super.key,
    required this.values,
    required this.labels,
    this.gridlines = 4,
  });

  /// One value per point, oldest first. Rendered on its own min/max, so a series that never
  /// approaches zero still fills the plot rather than flattening against the top.
  final List<num> values;

  /// Axis label per point — same length as [values].
  final List<String> labels;

  /// Horizontal hairlines behind the plot.
  final int gridlines;

  /// Height reserved beneath the plot for the month axis.
  static const axisHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The axis is a fixed band under a flexible plot, so a card shorter than the band has
    // nothing left to give it and the column overflows its own box. On a short window the
    // band gives way instead — a clipped axis is a worse chart, an overflow is a broken one.
    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = constraints.hasBoundedHeight
            ? math.min(axisHeight, constraints.maxHeight)
            : axisHeight;

        return Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _AreaLinePainter(
                    values: values,
                    gridlines: gridlines,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: axis,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: axisHeight,
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
  _AreaLinePainter({required this.values, required this.gridlines});

  final List<num> values;
  final int gridlines;

  static const _stroke = 2.5;
  static const _dotRadius = 5.0;
  static const _fillAlpha = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by the dot so the current point isn't clipped by the plot's own edge.
    final plot = Rect.fromLTWH(
      _dotRadius,
      _dotRadius,
      size.width - _dotRadius * 2,
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
          plot.left + plot.width * (i / (values.length - 1)),
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

    // The current point, ringed in the card's own surface so the dot reads as sitting on the
    // line rather than as a bead threaded onto it.
    canvas.drawCircle(
      points.last,
      _dotRadius,
      Paint()..color = AppColors.surfaceRaised,
    );
    canvas.drawCircle(
      points.last,
      _dotRadius - _stroke / 2,
      Paint()..color = AppColors.iris,
    );
  }

  @override
  bool shouldRepaint(_AreaLinePainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.gridlines != gridlines;
}
