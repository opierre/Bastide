import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chart_frame.dart';
import 'chart_scale.dart';
import 'chart_style.dart';

/// Bars by sign (`docs/design/00-design-system.md` §9): one bar per period,
/// at most 18 px wide, radius 3 on the outer end; `positive` above zero,
/// `negative` below. A period in [provisional] (the month in progress) is
/// hatched rather than filled. The value axis fits the bars' own range
/// ([ChartScale.signedBars]), so they fill the plot.
class SignedBarChart extends StatelessWidget {
  const SignedBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.provisional = const {},
    this.valueLabel,
    this.tooltips,
    this.minStep = 1,
  });

  /// One value per period, oldest first.
  final List<num> values;
  final List<String> labels;
  final Set<int> provisional;
  final String Function(num value)? valueLabel;
  final List<InlineSpan>? tooltips;
  final num minStep;

  /// About how many gaps the gridlines leave, as on every chart frame.
  static const gridlines = 4;

  /// The bar of period [index], from zero to its value.
  static Rect barRect(ChartGeometry g, int index, num value) {
    final width = math.min(AppChart.barMaxWidth, g.slot * 0.6);
    final zero = g.y(0);
    final top = g.y(value);
    return Rect.fromLTRB(
      g.x(index) - width / 2,
      math.min(zero, top),
      g.x(index) + width / 2,
      math.max(zero, top),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Rect> bars(ChartGeometry g) => [
      for (var i = 0; i < values.length; i++) barRect(g, i, values[i]),
    ];

    return ChartFrame(
      scaleValues: values,
      scale: ChartScale.signedBars(
        values,
        intervals: gridlines,
        minStep: minStep,
      ),
      labels: labels,
      valueLabel: valueLabel,
      tooltips: tooltips,
      minStep: minStep,
      gridlines: gridlines,
      slotKeyPrefix: 'signedBarSlot',
      tooltipKey: const Key('signedBarTooltip'),
      marks: bars,
      anchors: (g) => [
        for (var i = 0; i < values.length; i++) Offset(g.x(i), g.y(values[i])),
      ],
      paintSeries: (canvas, g, colors, hovered) {
        for (var i = 0; i < values.length; i++) {
          final value = values[i];
          if (value == 0) continue;
          final rect = barRect(g, i, value);
          const r = Radius.circular(AppChart.barRadius);
          final shape = value > 0
              ? RRect.fromRectAndCorners(rect, topLeft: r, topRight: r)
              : RRect.fromRectAndCorners(rect, bottomLeft: r, bottomRight: r);
          final color = value > 0 ? colors.positive : colors.negative;
          if (provisional.contains(i)) {
            ChartPaints.hatch(canvas, Path()..addRRect(shape), color);
          } else {
            canvas.drawRRect(shape, Paint()..color = color);
          }
        }
      },
    );
  }
}

/// Stacked bars (`00` §9), capital and interest: [base] in `accent` at the
/// bottom, [top] in `textTertiary` above, 2 px apart, radius 2 on top. Both
/// are non-negative. A period in [provisional] is hatched.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({
    super.key,
    required this.base,
    required this.top,
    required this.labels,
    this.provisional = const {},
    this.valueLabel,
    this.tooltips,
    this.minStep = 1,
  });

  final List<num> base;
  final List<num> top;
  final List<String> labels;
  final Set<int> provisional;
  final String Function(num value)? valueLabel;
  final List<InlineSpan>? tooltips;
  final num minStep;

  /// The two segments of period [index]: base, then top (empty when 0).
  static (Rect, Rect) segments(ChartGeometry g, int index, num base, num top) {
    final width = math.min(AppChart.barMaxWidth, g.slot * 0.6);
    final left = g.x(index) - width / 2;
    final zero = g.y(0);
    final baseTop = g.y(base);
    final lower = Rect.fromLTRB(left, baseTop, left + width, zero);
    if (top <= 0) return (lower, Rect.zero);
    final upperBottom = baseTop - (base > 0 ? AppChart.stackGap : 0);
    final upperTop = math.min(upperBottom, g.y(base + top));
    return (lower, Rect.fromLTRB(left, upperTop, left + width, upperBottom));
  }

  @override
  Widget build(BuildContext context) {
    assert(base.length == top.length, 'one top per base');
    final totals = [for (var i = 0; i < base.length; i++) base[i] + top[i]];

    return ChartFrame(
      scaleValues: [...totals, 0],
      labels: labels,
      valueLabel: valueLabel,
      tooltips: tooltips,
      minStep: minStep,
      slotKeyPrefix: 'stackedBarSlot',
      tooltipKey: const Key('stackedBarTooltip'),
      marks: (g) => [
        for (var i = 0; i < base.length; i++)
          Rect.fromLTRB(
            segments(g, i, base[i], top[i]).$1.left,
            g.y(totals[i]),
            segments(g, i, base[i], top[i]).$1.right,
            g.y(0),
          ),
      ],
      anchors: (g) => [
        for (var i = 0; i < base.length; i++) Offset(g.x(i), g.y(totals[i])),
      ],
      paintSeries: (canvas, g, colors, hovered) {
        const r = Radius.circular(AppChart.stackRadius);
        for (var i = 0; i < base.length; i++) {
          final (lower, upper) = segments(g, i, base[i], top[i]);
          final hasTop = !upper.isEmpty;
          void draw(Rect rect, Color color, {required bool rounded}) {
            if (rect.isEmpty) return;
            final shape = rounded
                ? RRect.fromRectAndCorners(rect, topLeft: r, topRight: r)
                : RRect.fromRectAndCorners(rect);
            if (provisional.contains(i)) {
              ChartPaints.hatch(canvas, Path()..addRRect(shape), color);
            } else {
              canvas.drawRRect(shape, Paint()..color = color);
            }
          }

          draw(lower, colors.accent, rounded: !hasTop);
          draw(upper, colors.textTertiary, rounded: true);
        }
      },
    );
  }
}
