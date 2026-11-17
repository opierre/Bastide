import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';

/// A deferred card's spending, one bar per settlement cycle
/// (`docs/design/16-account-detail.md` §Variant). A card's balance resets each
/// month, so a line through it reads as a sawtooth; the cycle totals are the
/// figure that means something.
///
/// Bars are expense red at 70%; the open cycle, still moving, is drawn as a
/// dashed outline instead. Framed in the shared curve style ([AppChart]) — the
/// same value gutter, labelled gridlines on clean ticks (see [ChartScale]),
/// slots, month axis and hover card as [AreaLine] — so the two charts sit
/// interchangeably in one card. Not animated, per the spec's motion rules.
class CycleBars extends StatefulWidget {
  const CycleBars({
    super.key,
    required this.values,
    required this.labels,
    required this.lastInProgress,
    required this.valueLabel,
    this.tooltips,
  });

  /// What each cycle charged, as a positive magnitude in minor units, oldest
  /// first.
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
  /// The cycle under the pointer — hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ChartPaints.labelStyle(context);
    final scale = _scale(widget.values);
    final levels = scale.ticks.map(widget.valueLabel).toList();
    final tooltips = widget.tooltips;
    final values = widget.values;

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
                    colors: context.colors,
                    values: values,
                    scale: scale,
                    lastInProgress: widget.lastInProgress,
                    hovered: _hovered,
                    levelLabels: levels,
                    labelStyle: labelStyle,
                  ),
                ),
              ),
              MouseRegion(
                onExit: (_) => setState(() => _hovered = null),
                child: Row(
                  children: [
                    const SizedBox(width: AppChart.valueGutter),
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: MouseRegion(
                          key: Key('cycleBarsSlot-$i'),
                          onEnter: (_) => setState(() => _hovered = i),
                          // The card is drawn, not a [Tooltip], so a screen
                          // reader still needs the cycle's figure on its slot.
                          child: Semantics(
                            label: tooltips == null || i >= tooltips.length
                                ? null
                                : tooltips[i].toPlainText(),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if ((_hovered, tooltips) case (
                final hovered?,
                final tooltips?,
              ) when hovered < tooltips.length && hovered < values.length)
                LineChartTooltip(
                  cardKey: Key('cycleBarsTooltip-$hovered'),
                  message: tooltips[hovered],
                  points: (size) => [
                    for (var i = 0; i < values.length; i++)
                      _barRect(values, scale, i, _plotRect(size)).topCenter,
                  ],
                  hovered: hovered,
                  pointRadius: 0,
                  // Bars, not a line: the card keeps clear of every one.
                  joinsNext: (_) => false,
                  marks: (size) => [
                    for (var i = 0; i < values.length; i++)
                      _barRect(values, scale, i, _plotRect(size)),
                  ],
                  leftBound: AppChart.valueGutter,
                ),
            ],
          ),
        ),
        SizedBox(
          height: AppChart.axisHeight,
          child: Row(
            children: [
              const SizedBox(width: AppChart.valueGutter),
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

/// The bars' scale: from zero, so a bar's height is its total, to a clean tick
/// past the tallest one — the same [ChartScale] the account's balance line
/// stands on. Minor units, so no gridline on cents.
ChartScale _scale(List<int> values) =>
    ChartScale.of([0, ...values], intervals: 2, minStep: 100);

/// Where the plot sits in the chart's box: right of the value gutter, inset a
/// little at the top so the top label isn't clipped. Shared by the painter and
/// the hover card, so the card can't drift off the bar it names.
Rect _plotRect(Size size) => Rect.fromLTWH(
  AppChart.valueGutter,
  _CycleBarsPainter._topInset,
  size.width - AppChart.valueGutter,
  size.height - _CycleBarsPainter._topInset,
);

/// Cycle [index]'s bar: [_CycleBarsPainter._maxBarWidth] at most, or 56 % of
/// its slot, from zero to its total.
Rect _barRect(List<int> values, ChartScale scale, int index, Rect plot) {
  final barWidth = math.min(
    _CycleBarsPainter._maxBarWidth,
    plot.width / values.length * 0.56,
  );
  final centre = plot.left + AreaLine.pointX(index, values.length, plot.width);
  final tip = scale.y(values[index], plot);
  final zero = scale.y(0, plot);
  return Rect.fromLTRB(
    centre - barWidth / 2,
    math.min(tip, zero),
    centre + barWidth / 2,
    math.max(tip, zero),
  );
}

class _CycleBarsPainter extends CustomPainter {
  /// The active theme's colours.
  final AppColors colors;

  _CycleBarsPainter({
    required this.colors,
    required this.values,
    required this.scale,
    required this.lastInProgress,
    required this.hovered,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<int> values;
  final ChartScale scale;
  final bool lastInProgress;
  final int? hovered;
  final List<String> levelLabels;
  final TextStyle labelStyle;

  static const _topInset = 4.0;
  static const _maxBarWidth = 28.0;
  static const _topRadius = 6.0;
  static const _baseRadius = 2.0;
  static const _barAlpha = 0.7;
  static const _hoverAlpha = 0.9;
  static const _openFillAlpha = 0.08;
  static const _openOutline = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in scale.ticks) scale.y(tick, plot)],
      labels: levelLabels,
      style: labelStyle,
    );

    for (var i = 0; i < values.length; i++) {
      final rect = RRect.fromRectAndCorners(
        _barRect(values, scale, i, plot),
        topLeft: const Radius.circular(_topRadius),
        topRight: const Radius.circular(_topRadius),
        bottomLeft: const Radius.circular(_baseRadius),
        bottomRight: const Radius.circular(_baseRadius),
      );
      final open = lastInProgress && i == values.length - 1;
      if (open) {
        canvas.drawRRect(
          rect,
          Paint()..color = colors.negative.withValues(alpha: _openFillAlpha),
        );
        canvas.drawPath(
          ChartPaints.dashed(Path()..addRRect(rect)),
          Paint()
            ..color = colors.negative
            ..style = PaintingStyle.stroke
            ..strokeWidth = _openOutline,
        );
      } else {
        final alpha = hovered == i ? _hoverAlpha : _barAlpha;
        canvas.drawRRect(
          rect,
          Paint()..color = colors.negative.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CycleBarsPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.scale != scale ||
      oldDelegate.lastInProgress != lastInProgress ||
      oldDelegate.hovered != hovered ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
