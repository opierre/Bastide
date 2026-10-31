import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/area_line.dart';

/// What each month put aside, one bar per month around a zero line: income
/// green above it, expense red below it for a month that spent more than it
/// earned. The direction doubles the color, so the sign never rests on hue
/// alone.
///
/// Bars rather than a line: each month's saving is its own figure, not a step
/// of a running total, and a line through twelve independent amounts would draw
/// a trend that isn't there. The last bar is the current month, still moving,
/// so it is drawn as a dashed outline — as the open cycle is on a card's chart.
///
/// Laid out like [AreaLine] (value gutter, slots, month axis) so the card reads
/// like the other charts. Not animated, per the spec's motion rules.
class SavingsBars extends StatefulWidget {
  const SavingsBars({
    super.key,
    required this.values,
    required this.labels,
    required this.valueLabel,
    this.tooltips,
  });

  /// Signed minor units per month, oldest first.
  final List<int> values;
  final List<String> labels;
  final String Function(num value) valueLabel;
  final List<InlineSpan>? tooltips;

  @override
  State<SavingsBars> createState() => _SavingsBarsState();
}

class _SavingsBarsState extends State<SavingsBars> {
  /// The slot under the pointer — hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    );
    final scale = _Scale.of(widget.values);
    final tooltips = widget.tooltips;

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SavingsBarsPainter(
                    values: widget.values,
                    scale: scale,
                    hovered: _hovered,
                    levelLabels: scale.levels.map(widget.valueLabel).toList(),
                    labelStyle: tabularNumberStyle(labelStyle),
                  ),
                ),
              ),
              MouseRegion(
                onExit: (_) => setState(() => _hovered = null),
                child: Row(
                  children: [
                    const SizedBox(width: AreaLine.valueGutter),
                    for (var i = 0; i < widget.values.length; i++)
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hovered = i),
                          child: tooltips == null
                              ? const SizedBox.expand()
                              : Tooltip(
                                  key: Key('savingsBarsTooltip-$i'),
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
          height: AreaLine.axisHeight,
          child: Row(
            children: [
              const SizedBox(width: AreaLine.valueGutter),
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

class _SavingsBarsPainter extends CustomPainter {
  _SavingsBarsPainter({
    required this.values,
    required this.scale,
    required this.hovered,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<int> values;
  final _Scale scale;
  final int? hovered;
  final List<String> levelLabels;
  final TextStyle labelStyle;

  static const _maxBarWidth = 22.0;
  static const _tipRadius = 5.0;
  static const _baseRadius = 2.0;
  static const _barAlpha = 0.7;
  static const _hoverAlpha = 0.9;
  static const _openFillAlpha = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    const gutter = AreaLine.valueGutter;
    final plot = Rect.fromLTWH(gutter, 4, size.width - gutter, size.height - 8);
    if (plot.width <= 0 || plot.height <= 0) return;

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    final levels = scale.levels;
    for (var i = 0; i < levels.length; i++) {
      final y = scale.y(levels[i], plot);
      canvas.drawLine(Offset(plot.left, y), Offset(size.width, y), grid);
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

    if (values.isEmpty) return;
    final zeroY = scale.y(0, plot);
    final slot = plot.width / values.length;
    final barWidth = math.min(_maxBarWidth, slot * 0.56);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == 0) continue;
      final centre = plot.left + AreaLine.pointX(i, values.length, plot.width);
      final valueY = scale.y(value.toDouble(), plot);
      final up = value > 0;
      // The rounded end is the tip, away from zero, whichever way the bar runs.
      const tip = Radius.circular(_tipRadius);
      const base = Radius.circular(_baseRadius);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(
          centre - barWidth / 2,
          up ? valueY : zeroY,
          centre + barWidth / 2,
          up ? zeroY : valueY,
        ),
        topLeft: up ? tip : base,
        topRight: up ? tip : base,
        bottomLeft: up ? base : tip,
        bottomRight: up ? base : tip,
      );
      final color = up ? AppColors.positive : AppColors.negative;
      if (i == values.length - 1) {
        canvas.drawRRect(
          rect,
          Paint()..color = color.withValues(alpha: _openFillAlpha),
        );
        _drawDashed(canvas, Path()..addRRect(rect), color);
      } else {
        final alpha = hovered == i ? _hoverAlpha : _barAlpha;
        canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: alpha));
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_SavingsBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.scale != scale ||
      oldDelegate.hovered != hovered ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
