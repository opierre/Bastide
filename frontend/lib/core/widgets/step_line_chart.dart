import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chart_frame.dart';
import 'chart_style.dart';

/// The step line of `docs/design/00-design-system.md` §9 (a subscription's
/// price): the line recipe drawn step-after, a 2 px `accent` line over a 10 %
/// area. Where the value changes, the new point takes a `warning` dot and a
/// 1 px `warning` 35 % vertical guide.
///
/// An optional [secondValues] series (net payments under an investment's
/// value) is a 1.5 px `textTertiary` step line with no area.
class StepLineChart extends StatelessWidget {
  const StepLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.secondValues,
    this.valueLabel,
    this.tooltips,
    this.minStep = 1,
  });

  /// One value per period, oldest first.
  final List<num> values;
  final List<String> labels;
  final List<num>? secondValues;
  final String Function(num value)? valueLabel;
  final List<InlineSpan>? tooltips;
  final num minStep;

  /// The indices whose value differs from the one before.
  static List<int> changes(List<num> values) => [
    for (var i = 1; i < values.length; i++)
      if (values[i] != values[i - 1]) i,
  ];

  /// The step-after path through [values]: flat across each period, then
  /// straight up or down at the next one.
  static Path stepPath(ChartGeometry g, List<num> values) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = g.x(i);
      final y = g.y(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path
          ..lineTo(x, g.y(values[i - 1]))
          ..lineTo(x, y);
      }
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final second = secondValues;

    return ChartFrame(
      scaleValues: [...values, ...?second],
      labels: labels,
      valueLabel: valueLabel,
      tooltips: tooltips,
      minStep: minStep,
      joinsLine: true,
      slotKeyPrefix: 'stepLineSlot',
      tooltipKey: const Key('stepLineTooltip'),
      anchors: (g) => [
        for (var i = 0; i < values.length; i++) Offset(g.x(i), g.y(values[i])),
      ],
      paintSeries: (canvas, g, colors, hovered) {
        if (values.isEmpty) return;
        final changed = changes(values);

        // Change guides first, under everything.
        final guide = Paint()
          ..color = colors.warning.withValues(alpha: AppChart.changeGuideAlpha)
          ..strokeWidth = AppChart.gridStroke;
        for (final i in changed) {
          canvas.drawLine(
            Offset(g.x(i), g.plot.top),
            Offset(g.x(i), g.plot.bottom),
            guide,
          );
        }

        if (second != null && second.length > 1) {
          canvas.drawPath(
            stepPath(g, second),
            ChartPaints.stroke(colors.textTertiary)
              ..strokeWidth = AppChart.secondLineStroke,
          );
        }

        final line = stepPath(g, values);
        if (values.length > 1) {
          final area = Path.from(line)
            ..lineTo(g.x(values.length - 1), g.plot.bottom)
            ..lineTo(g.x(0), g.plot.bottom)
            ..close();
          canvas
            ..drawPath(area, ChartPaints.area(colors.accent))
            ..drawPath(line, ChartPaints.stroke(colors.accent));
        }

        final large = {values.length - 1, ?hovered};
        for (var i = 0; i < values.length; i++) {
          final isChange = changed.contains(i);
          if (!large.contains(i) &&
              !isChange &&
              values.length > AppChart.dotCeiling) {
            continue;
          }
          ChartPaints.dot(
            colors,
            canvas,
            Offset(g.x(i), g.y(values[i])),
            large.contains(i)
                ? AppChart.currentDotRadius
                : AppChart.pointDotRadius,
            isChange ? colors.warning : colors.accent,
          );
        }
      },
    );
  }
}
