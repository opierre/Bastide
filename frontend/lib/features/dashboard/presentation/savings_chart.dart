import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/area_line.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../application/dashboard_controller.dart';

/// What each month put aside, drawn around a zero line in one of two [SavingsChartView]s.
///
/// - **Bars**: one bar per month, income green above zero, expense red below it for a
///   month that spent more than it earned. Each month's saving is its own figure, not a
///   step of a running total, so bars are the default.
/// - **Line**: the same twelve figures joined in order, which reads the direction over
///   many months better. Each point is still dotted in its sign's color, the area between
///   the line and zero is washed in iris as on the Synthèse's « Patrimoine net », and a
///   dashed zero baseline marks where a month turns negative.
///
/// Either way the direction doubles the color, so the sign never rests on hue alone, and
/// the last month — the current one, still moving — is drawn open: a dashed outline bar,
/// or a dashed last segment ending on a hollow dot.
///
/// Hovering a month names its figure in a tooltip anchored to the mark itself, not the card
/// edge: beside the bar's tip or the line's dot, on the side away from zero (above a saving,
/// below a shortfall). It floats in the overlay like any tooltip, so it may reach past the
/// plot into the card's padding rather than cover the mark.
///
/// Both views share one frame: the [_Scale], the labelled gridlines, the hover slots, the
/// tooltip and the month axis. Only the mark layer differs, so a reference drawn over the marks (an
/// average line, say) is one more step in [_SavingsChartPainter.paint] and lands in both.
///
/// Laid out like [AreaLine] (value gutter, slots, month axis) so the card reads like the
/// other charts. Not animated, per the spec's motion rules.
class SavingsChart extends StatefulWidget {
  const SavingsChart({
    super.key,
    required this.values,
    required this.labels,
    required this.valueLabel,
    this.view = SavingsChartView.bars,
    this.tooltips,
  });

  /// Signed minor units per month, oldest first.
  final List<int> values;
  final List<String> labels;
  final String Function(num value) valueLabel;
  final SavingsChartView view;
  final List<InlineSpan>? tooltips;

  @override
  State<SavingsChart> createState() => _SavingsChartState();
}

class _SavingsChartState extends State<SavingsChart> {
  /// The slot under the pointer — hover ephemera, not chart state.
  int? _hovered;

  /// The hovered month's tooltip lives in the [Overlay], tied to the plot by [_link], as a
  /// [Tooltip] does: the plot keeps little headroom past its tallest and deepest months, so
  /// a tooltip held inside it would have to cover the very mark it names.
  final _link = LayerLink();
  final _tooltip = OverlayPortalController();

  void _hover(int? index) {
    setState(() => _hovered = index);
    if (index != null && widget.tooltips != null) {
      _tooltip.show();
    } else {
      _tooltip.hide();
    }
  }

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
          child: LayoutBuilder(
            builder: (context, constraints) => CompositedTransformTarget(
              link: _link,
              child: OverlayPortal(
                controller: _tooltip,
                overlayChildBuilder: (context) =>
                    _hoveredTooltip(constraints.biggest, scale),
                child: _plot(scale, labelStyle, tooltips),
              ),
            ),
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

  /// The marks, and one full-height hover slot per month over them.
  Widget _plot(
    _Scale scale,
    TextStyle labelStyle,
    List<InlineSpan>? tooltips,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SavingsChartPainter(
            values: widget.values,
            view: widget.view,
            scale: scale,
            hovered: _hovered,
            levelLabels: scale.levels.map(widget.valueLabel).toList(),
            labelStyle: tabularNumberStyle(labelStyle),
          ),
        ),
      ),
      MouseRegion(
        onExit: (_) => _hover(null),
        child: Row(
          children: [
            const SizedBox(width: AreaLine.valueGutter),
            for (var i = 0; i < widget.values.length; i++)
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => _hover(i),
                  // The tooltip is drawn, not a [Tooltip], so a screen reader still
                  // needs the month's figure on its slot.
                  child: Semantics(
                    label: tooltips?[i].toPlainText(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// The hovered month's tooltip, centred on its mark and [_tooltipGap] clear of it on the
  /// side away from zero: over a saving's bar tip or dot (and an empty month's), under a
  /// shortfall's — so it names the mark without covering it or the line back to zero.
  Widget _hoveredTooltip(Size size, _Scale scale) {
    final hovered = _hovered;
    final tooltips = widget.tooltips;
    if (hovered == null ||
        tooltips == null ||
        hovered >= widget.values.length) {
      return const SizedBox.shrink();
    }
    final mark = _markPoint(widget.values, scale, hovered, _plotRect(size));
    final up = widget.values[hovered] >= 0;
    final clearance = switch (widget.view) {
      SavingsChartView.bars => _tooltipGap,
      SavingsChartView.line =>
        _SavingsChartPainter.hoverDotOuterRadius + _tooltipGap,
    };
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: mark,
        child: IgnorePointer(
          child: FractionalTranslation(
            translation: Offset(-0.5, up ? -1 : 0),
            child: Padding(
              padding: EdgeInsets.only(
                top: up ? 0 : clearance,
                bottom: up ? clearance : 0,
              ),
              child: ChartTooltip(
                key: Key('savingsChartTooltip-$hovered'),
                message: tooltips[hovered],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Space between a mark's edge and its tooltip.
const _tooltipGap = AppSpacing.sm;

/// Where the plot sits in the chart's box, right of the value gutter and inset a little
/// top and bottom. Shared by the painter and the tooltip, so a tooltip can't drift off the
/// mark it names.
Rect _plotRect(Size size) => Rect.fromLTWH(
  AreaLine.valueGutter,
  4,
  size.width - AreaLine.valueGutter,
  size.height - 8,
);

/// Month [index]'s mark: its slot's centre, at its value on the shared scale — the line's
/// dot, or the bar's tip.
Offset _markPoint(List<int> values, _Scale scale, int index, Rect plot) =>
    Offset(
      plot.left + AreaLine.pointX(index, values.length, plot.width),
      scale.y(values[index].toDouble(), plot),
    );

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

class _SavingsChartPainter extends CustomPainter {
  _SavingsChartPainter({
    required this.values,
    required this.view,
    required this.scale,
    required this.hovered,
    required this.levelLabels,
    required this.labelStyle,
  });

  final List<int> values;
  final SavingsChartView view;
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

  /// The line view's stroke and dots, as on [AreaLine], whose iris line this chart drew
  /// before it took bars.
  static const _lineStroke = 2.5;
  static const _dotRadius = 4.0;
  static const _hoverDotRadius = 5.0;
  static const _dotRing = 1.5;

  /// The line view's area, at the Synthèse « Patrimoine net » chart's 10 %.
  static const _areaAlpha = 0.10;

  /// The hovered dot's reach, ring included — what the line view's tooltip clears.
  static const hoverDotOuterRadius = _hoverDotRadius + _dotRing;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;

    _paintGrid(canvas, size, plot);
    if (values.isEmpty) return;
    switch (view) {
      case SavingsChartView.bars:
        _paintBars(canvas, plot);
      case SavingsChartView.line:
        _paintLine(canvas, size, plot);
    }
    // Overlays shared by both views (a reference line on the same scale) paint here,
    // after the marks.
  }

  /// The labelled gridlines both views stand on.
  void _paintGrid(Canvas canvas, Size size, Rect plot) {
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
  }

  /// Month [index]'s position: its slot's centre, at its value on the shared scale.
  Offset _point(int index, Rect plot) => _markPoint(values, scale, index, plot);

  void _paintBars(Canvas canvas, Rect plot) {
    final zeroY = scale.y(0, plot);
    final slot = plot.width / values.length;
    final barWidth = math.min(_maxBarWidth, slot * 0.56);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == 0) continue;
      final point = _point(i, plot);
      final up = value > 0;
      // The rounded end is the tip, away from zero, whichever way the bar runs.
      const tip = Radius.circular(_tipRadius);
      const base = Radius.circular(_baseRadius);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(
          point.dx - barWidth / 2,
          up ? point.dy : zeroY,
          point.dx + barWidth / 2,
          up ? zeroY : point.dy,
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

  void _paintLine(Canvas canvas, Size size, Rect plot) {
    final points = [for (var i = 0; i < values.length; i++) _point(i, plot)];

    // The zero baseline, dashed as on [AreaLine]'s `markZero`, so a dip below it reads
    // as a month that spent more than it earned. Drawn whenever zero is not the plot's
    // own floor, where the bottom gridline already marks it.
    final zeroY = scale.y(0, plot);
    if (scale.bottom < 0) {
      final dash = Paint()
        ..color = AppColors.borderDashed
        ..strokeWidth = 1;
      for (var x = plot.left; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, zeroY),
          Offset(math.min(x + 4, size.width), zeroY),
          dash,
        );
      }
    }

    // The area between the line and zero, as under the Synthèse's « Patrimoine net »: an
    // iris wash closed on the zero line rather than the plot's floor, so a saving fills up
    // to its point and a shortfall down to its own, the same way. Under the line, so the
    // stroke and dots stay crisp over it.
    if (points.length > 1) {
      canvas.drawPath(
        Path()
          ..addPolygon(points, false)
          ..lineTo(points.last.dx, zeroY)
          ..lineTo(points.first.dx, zeroY)
          ..close(),
        Paint()..color = AppColors.iris.withValues(alpha: _areaAlpha),
      );
    }

    final stroke = Paint()
      ..color = AppColors.iris
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineStroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // Settled months as one solid path; the segment into the open month dashed, as the
    // open bar is outlined.
    final settled = points.length > 1
        ? points.sublist(0, points.length - 1)
        : points;
    canvas.drawPath(Path()..addPolygon(settled, false), stroke);
    if (points.length > 1) {
      _drawDashed(
        canvas,
        Path()
          ..moveTo(points[points.length - 2].dx, points[points.length - 2].dy)
          ..lineTo(points.last.dx, points.last.dy),
        AppColors.iris,
        strokeWidth: _lineStroke,
      );
    }

    // A dot per month in its sign's color, ringed in the card's surface so it reads as
    // sitting on the line. The open month's dot is hollow.
    for (var i = 0; i < points.length; i++) {
      final radius = hovered == i ? _hoverDotRadius : _dotRadius;
      final color = values[i] < 0 ? AppColors.negative : AppColors.positive;
      canvas.drawCircle(
        points[i],
        radius + _dotRing,
        Paint()..color = AppColors.surfaceRaised,
      );
      if (i == points.length - 1) {
        canvas.drawCircle(
          points[i],
          radius - 0.75,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        canvas.drawCircle(points[i], radius, Paint()..color = color);
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Color color, {
    double strokeWidth = 1.5,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_SavingsChartPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.view != view ||
      oldDelegate.scale != scale ||
      oldDelegate.hovered != hovered ||
      !listEquals(oldDelegate.levelLabels, levelLabels) ||
      oldDelegate.labelStyle != labelStyle;
}
