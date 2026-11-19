import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chart_frame.dart';
import 'chart_style.dart';

/// The line / area of `docs/design/00-design-system.md` §9 (balances, net
/// worth, a loan's trajectory): a 2 px `accent` line with round joins over an
/// `accent` 10 % area; a 4 px dot ringed in `bg` on the last point and on the
/// hovered one; a 3 px dot per point while there are at most 24.
///
/// When the series crosses zero the frame draws the zero line, the area
/// stands on it, and the part below it takes `negative` at 10 %.
class LineAreaChart extends StatelessWidget {
  const LineAreaChart({
    super.key,
    required this.values,
    required this.labels,
    this.valueLabel,
    this.tooltips,
    this.minStep = 1,
  });

  /// One value per period, oldest first.
  final List<num> values;
  final List<String> labels;
  final String Function(num value)? valueLabel;
  final List<InlineSpan>? tooltips;
  final num minStep;

  /// Whether [values] hold both signs, so the area stands on zero.
  static bool crossesZero(List<num> values) =>
      values.any((v) => v < 0) && values.any((v) => v > 0);

  @override
  Widget build(BuildContext context) {
    final crosses = crossesZero(values);

    return ChartFrame(
      scaleValues: values,
      labels: labels,
      valueLabel: valueLabel,
      tooltips: tooltips,
      minStep: minStep,
      joinsLine: true,
      slotKeyPrefix: 'lineAreaSlot',
      tooltipKey: const Key('lineAreaTooltip'),
      anchors: (g) => [
        for (var i = 0; i < values.length; i++) Offset(g.x(i), g.y(values[i])),
      ],
      paintSeries: (canvas, g, colors, hovered) {
        if (values.isEmpty) return;
        final points = [
          for (var i = 0; i < values.length; i++)
            Offset(g.x(i), g.y(values[i])),
        ];

        if (points.length > 1) {
          final line = Path()..moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            line.lineTo(point.dx, point.dy);
          }
          final base = crosses ? g.y(0) : g.plot.bottom;
          final area = Path.from(line)
            ..lineTo(points.last.dx, base)
            ..lineTo(points.first.dx, base)
            ..close();
          final plot = g.plot;
          // The area is split at its base: `accent` above, `negative` below.
          canvas
            ..save()
            ..clipRect(Rect.fromLTRB(plot.left, plot.top, plot.right, base))
            ..drawPath(area, ChartPaints.area(colors.accent))
            ..restore();
          if (crosses) {
            canvas
              ..save()
              ..clipRect(
                Rect.fromLTRB(plot.left, base, plot.right, plot.bottom),
              )
              ..drawPath(area, ChartPaints.negativeArea(colors))
              ..restore();
          }
          canvas.drawPath(line, ChartPaints.stroke(colors.accent));
        }

        final large = {points.length - 1, ?hovered};
        for (var i = 0; i < points.length; i++) {
          final isLarge = large.contains(i);
          if (!isLarge && points.length > AppChart.dotCeiling) continue;
          ChartPaints.dot(
            colors,
            canvas,
            points[i],
            isLarge ? AppChart.currentDotRadius : AppChart.pointDotRadius,
            colors.accent,
          );
        }
      },
    );
  }
}
