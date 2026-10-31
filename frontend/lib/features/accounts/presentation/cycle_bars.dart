import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/area_line.dart';

/// A deferred card's spending, one bar per settlement cycle
/// (`docs/design/16-account-detail.md` §Variant). A card's balance resets each
/// month, so a line through it reads as a sawtooth; the cycle totals are the
/// figure that means something.
///
/// Bars are expense red at 70%; the open cycle, still moving, is drawn as a
/// dashed outline instead. Laid out like [AreaLine] — the same value gutter,
/// slots and month axis — so the two charts sit interchangeably in one card.
/// Not animated, per the spec's motion rules.
class CycleBars extends StatefulWidget {
  const CycleBars({
    super.key,
    required this.values,
    required this.labels,
    required this.lastInProgress,
    required this.valueLabel,
    this.tooltips,
  });

  /// What each cycle charged, as a positive magnitude, oldest first.
  final List<int> values;
  final List<String> labels;

  /// Whether the last bar is the open cycle.
  final bool lastInProgress;
  final String Function(num value) valueLabel;
  final List<InlineSpan>? tooltips;

  @override
  State<CycleBars> createState() => _CycleBarsState();
}

class _CycleBarsState extends State<CycleBars> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    );
    final top = _niceTop(widget.values);
    final levels = [0, top / 2, top].map(widget.valueLabel).toList();
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
                  painter: _CycleBarsPainter(
                    values: widget.values,
                    top: top,
                    lastInProgress: widget.lastInProgress,
                    hovered: _hovered,
                    levelLabels: levels,
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
                                  key: Key('cycleBarsTooltip-$i'),
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

/// The value at the top gridline: the tallest bar plus headroom, so it never
/// touches the card's title. Never zero, so an empty series still lays out.
double _niceTop(List<int> values) {
  final highest = values.isEmpty ? 0 : values.reduce(math.max);
  return highest <= 0 ? 1 : highest * 1.15;
}

class _CycleBarsPainter extends CustomPainter {
  _CycleBarsPainter({
    required this.values,
    required this.top,
    required this.lastInProgress,
    required this.hovered,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<int> values;
  final double top;
  final bool lastInProgress;
  final int? hovered;
  final List<String> levelLabels;
  final TextStyle labelStyle;

  static const _maxBarWidth = 28.0;
  static const _topRadius = 6.0;
  static const _baseRadius = 2.0;
  static const _barAlpha = 0.7;
  static const _hoverAlpha = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    const gutter = AreaLine.valueGutter;
    final plot = Rect.fromLTWH(gutter, 4, size.width - gutter, size.height - 4);
    if (plot.width <= 0) return;

    final grid = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (var i = 0; i < levelLabels.length; i++) {
      final y = plot.bottom - plot.height * (i / (levelLabels.length - 1));
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
    final slot = plot.width / values.length;
    final barWidth = math.min(_maxBarWidth, slot * 0.56);
    for (var i = 0; i < values.length; i++) {
      final height = plot.height * (values[i] / top);
      final centre = plot.left + AreaLine.pointX(i, values.length, plot.width);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centre - barWidth / 2,
          plot.bottom - height,
          barWidth,
          height,
        ),
        topLeft: const Radius.circular(_topRadius),
        topRight: const Radius.circular(_topRadius),
        bottomLeft: const Radius.circular(_baseRadius),
        bottomRight: const Radius.circular(_baseRadius),
      );
      final open = lastInProgress && i == values.length - 1;
      if (open) {
        canvas.drawRRect(
          rect,
          Paint()..color = AppColors.negative.withValues(alpha: 0.08),
        );
        _drawDashed(canvas, Path()..addRRect(rect));
      } else {
        final alpha = hovered == i ? _hoverAlpha : _barAlpha;
        canvas.drawRRect(
          rect,
          Paint()..color = AppColors.negative.withValues(alpha: alpha),
        );
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path) {
    final paint = Paint()
      ..color = AppColors.negative
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
  bool shouldRepaint(_CycleBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.top != top ||
      oldDelegate.lastInProgress != lastInProgress ||
      oldDelegate.hovered != hovered ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
