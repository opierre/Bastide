import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'chart_scale.dart';
import 'chart_style.dart';
import 'chart_tooltip.dart';

/// Where a chart's periods and values fall inside its plot. Periods sit at
/// the centre of equal slots, so a mark stands over its own axis label.
@immutable
class ChartGeometry {
  const ChartGeometry({
    required this.plot,
    required this.scale,
    required this.count,
  });

  final Rect plot;
  final ChartScale scale;
  final int count;

  double get slot => count == 0 ? plot.width : plot.width / count;

  /// The horizontal centre of period [index].
  double x(int index) => plot.left + slot * (index + 0.5);

  /// Where [value] is drawn.
  double y(num value) => scale.y(value, plot);
}

/// Paints one chart's series over the shared frame.
typedef ChartSeriesPainter =
    void Function(
      Canvas canvas,
      ChartGeometry geometry,
      AppColors colors,
      int? hovered,
    );

/// The one chart frame of `docs/design/00-design-system.md` §9, around a
/// series a chart paints itself: the value axis in a 56 px gutter, labels
/// 11 `textTertiary` ending 8 px before the plot; 1 px `line` gridlines on
/// clean ticks; the zero line in `lineStrong` when the values cross it; the
/// category axis in a 22 px band beneath. No vertical gridline, no border,
/// no animation.
///
/// The hit area of a period is its full column. Hovering it shows the
/// period's tooltip at once, clear of the marks ([marks]) and points
/// ([anchors]).
class ChartFrame extends StatefulWidget {
  const ChartFrame({
    super.key,
    required this.scaleValues,
    this.scale,
    required this.labels,
    required this.paintSeries,
    required this.anchors,
    this.marks,
    this.joinsLine = false,
    this.valueLabel,
    this.tooltips,
    this.gridlines = 4,
    this.minStep = 1,
    this.slotKeyPrefix = 'chartSlot',
    this.tooltipKey = const Key('chartTooltip'),
  });

  /// Every value the plot must hold.
  final List<num> scaleValues;

  /// The value range and gridlines, when the chart frames its series its
  /// own way (bars by sign); otherwise the padded [ChartScale.of] of
  /// [scaleValues].
  final ChartScale? scale;

  /// The category axis, one label per period.
  final List<String> labels;

  final ChartSeriesPainter paintSeries;

  /// The point of each period the tooltip keeps clear of.
  final List<Offset> Function(ChartGeometry geometry) anchors;

  /// The bar of each period, for bar charts.
  final List<Rect> Function(ChartGeometry geometry)? marks;

  /// Whether the [anchors] are joined by a line the tooltip avoids.
  final bool joinsLine;

  /// Formats a value for the left axis; without it the chart has no gutter.
  final String Function(num value)? valueLabel;

  /// The hover card per period. Spans, so the caller signs and colours each
  /// figure per §2.3.
  final List<InlineSpan>? tooltips;

  final int gridlines;

  /// The smallest gap between two gridlines; a chart of minor units
  /// passes 100.
  final num minStep;

  final String slotKeyPrefix;
  final Key tooltipKey;

  @override
  State<ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<ChartFrame> {
  /// The period under the pointer: hover ephemera, not chart state.
  int? _hovered;

  ChartGeometry _geometry(Size size, ChartScale scale, double gutter) =>
      ChartGeometry(
        plot: Rect.fromLTWH(
          gutter,
          AppChart.dotReach,
          math.max(0, size.width - gutter),
          math.max(0, size.height - AppChart.dotReach * 2),
        ),
        scale: scale,
        count: widget.labels.length,
      );

  @override
  Widget build(BuildContext context) {
    final labelStyle = ChartPaints.labelStyle(context);
    final valueLabel = widget.valueLabel;
    final gutter = valueLabel == null ? 0.0 : AppChart.valueGutter;
    final scale =
        widget.scale ??
        ChartScale.of(
          widget.scaleValues,
          intervals: widget.gridlines,
          minStep: widget.minStep,
        );
    final levels = valueLabel == null
        ? const <String>[]
        : scale.ticks.map(valueLabel).toList();
    final tooltips = widget.tooltips;
    final count = widget.labels.length;

    // The axis is a fixed band under a flexible plot, so a box shorter than
    // the band would overflow. There the band gives way instead: a clipped
    // axis is a worse chart, an overflow is a broken one.
    return LayoutBuilder(
      builder: (context, constraints) {
        final axisHeight = constraints.hasBoundedHeight
            ? math.min(AppChart.axisHeight, constraints.maxHeight)
            : AppChart.axisHeight;

        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _FramePainter(
                        colors: context.colors,
                        geometryFor: (size) => _geometry(size, scale, gutter),
                        levels: levels,
                        labelStyle: labelStyle,
                        hovered: _hovered,
                        paintSeries: widget.paintSeries,
                      ),
                    ),
                  ),
                  MouseRegion(
                    onExit: (_) => setState(() => _hovered = null),
                    child: Row(
                      children: [
                        SizedBox(width: gutter),
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: MouseRegion(
                              key: Key('${widget.slotKeyPrefix}-$i'),
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
                    ),
                  ),
                  if ((_hovered, tooltips) case (
                    final hovered?,
                    final tooltips?,
                  ) when hovered < tooltips.length && hovered < count)
                    LineChartTooltip(
                      cardKey: widget.tooltipKey,
                      message: tooltips[hovered],
                      points: (size) =>
                          widget.anchors(_geometry(size, scale, gutter)),
                      marks: widget.marks == null
                          ? null
                          : (size) =>
                                widget.marks!(_geometry(size, scale, gutter)),
                      joinsNext: widget.joinsLine ? null : (_) => false,
                      hovered: hovered,
                      pointRadius: AppChart.dotReach,
                      leftBound: gutter,
                    ),
                ],
              ),
            ),
            SizedBox(
              height: axisHeight,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: AppChart.axisHeight,
                  maxHeight: AppChart.axisHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(width: gutter),
                      for (final label in widget.labels)
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle,
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

class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.colors,
    required this.geometryFor,
    required this.levels,
    required this.labelStyle,
    required this.hovered,
    required this.paintSeries,
  });

  final AppColors colors;
  final ChartGeometry Function(Size size) geometryFor;
  final List<String> levels;
  final TextStyle labelStyle;
  final int? hovered;
  final ChartSeriesPainter paintSeries;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = geometryFor(size);
    final plot = geometry.plot;
    if (plot.width <= 0 || plot.height <= 0) return;
    final scale = geometry.scale;

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in scale.ticks) geometry.y(tick)],
      labels: levels,
      style: labelStyle,
    );
    if (scale.min < 0 && scale.max > 0) {
      final zero = geometry.y(0);
      ChartPaints.zeroLine(
        colors,
        canvas,
        Offset(plot.left, zero),
        Offset(size.width, zero),
      );
    }
    paintSeries(canvas, geometry, colors, hovered);
  }

  // The series painter is a closure, which can't be compared; a chart
  // repaints only when its widget rebuilds.
  @override
  bool shouldRepaint(_FramePainter oldDelegate) => true;
}
