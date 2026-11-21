import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/chart_scale.dart';
import '../../../core/widgets/chart_style.dart';
import '../../../core/widgets/chart_tooltip.dart';
import '../domain/placement_timeline.dart';

/// The inspector chart of `17-placements.md` §Inspector 5: the declared
/// value as a line over its area, one dot per declaration; net payments as
/// the second series, a 1.5 px `textTertiary` step line (`00` §9).
///
/// Between two declarations the value is held flat, so the line steps and
/// the area under it is hatched: only the dots are facts.
///
/// Time runs to scale: declarations come at whatever dates the user copied
/// them, so the frame's one-slot-per-period axis would space a three-year gap
/// like a three-day one. The frame itself (gutter, gridlines, labels, hover
/// card) is the shared one.
class PlacementChart extends StatefulWidget {
  const PlacementChart({
    super.key,
    required this.points,
    required this.valueLabel,
    required this.tooltipFor,
    required this.semanticLabel,
  });

  /// Oldest first; see [placementTimeline].
  final List<TimelinePoint> points;

  /// Formats a value for the left axis.
  final String Function(num value) valueLabel;

  /// The hover card of one point.
  final InlineSpan Function(TimelinePoint point) tooltipFor;

  final String semanticLabel;

  @override
  State<PlacementChart> createState() => _PlacementChartState();
}

class _PlacementChartState extends State<PlacementChart> {
  /// The point under the pointer: hover ephemera, not chart state.
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final labelStyle = ChartPaints.labelStyle(context);
    final points = widget.points;
    final scale = ChartScale.of(
      [
        for (final point in points) ...[
          point.netPaymentsMinor,
          ?point.valueMinor,
        ],
      ],
      intervals: 4,
      minStep: 100,
    );

    return Semantics(
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final geometry = _TimeGeometry(
            size: size,
            scale: scale,
            points: points,
          );
          final hovered = _hovered;

          return MouseRegion(
            onHover: (event) => setState(
              () => _hovered = geometry.nearest(event.localPosition.dx),
            ),
            onExit: (_) => setState(() => _hovered = null),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _PlacementPainter(
                    colors: context.colors,
                    geometry: geometry,
                    hovered: hovered,
                    levels: scale.ticks.map(widget.valueLabel).toList(),
                    ticks: _timeTicks(geometry.start, geometry.end, locale),
                    labelStyle: labelStyle,
                  ),
                ),
                if (hovered != null && hovered < points.length)
                  LineChartTooltip(
                    cardKey: const Key('placementChartTooltip'),
                    message: widget.tooltipFor(points[hovered]),
                    points: (_) => geometry.anchors,
                    hovered: hovered,
                    pointRadius: AppChart.dotReach,
                    leftBound: AppChart.valueGutter,
                    bottomInset: AppChart.axisHeight,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One labelled date on the time axis.
typedef _TimeTick = ({DateTime date, String label});

/// Years past two years of history, quarters past three months, months
/// below that.
List<_TimeTick> _timeTicks(DateTime start, DateTime end, String locale) {
  final days = end.difference(start).inDays;
  final ticks = <_TimeTick>[];
  if (days >= 730) {
    for (var year = start.year + 1; year <= end.year; year++) {
      ticks.add((date: DateTime(year), label: '$year'));
    }
  } else {
    final step = days >= 90 ? 3 : 1;
    final format = DateFormat('MMM yy', locale);
    var cursor = DateTime(start.year, start.month + 1);
    while (!cursor.isAfter(end)) {
      if ((cursor.month - 1) % step == 0) {
        ticks.add((date: cursor, label: format.format(cursor)));
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }
  return ticks;
}

/// Where dates and values fall in the plot.
class _TimeGeometry {
  _TimeGeometry({required Size size, required this.scale, required this.points})
    : plot = Rect.fromLTRB(
        AppChart.valueGutter,
        AppChart.dotReach,
        math.max(AppChart.valueGutter, size.width - AppChart.dotReach),
        math.max(
          AppChart.dotReach,
          size.height - AppChart.axisHeight - AppChart.dotReach,
        ),
      ),
      start = points.isEmpty ? DateTime(2000) : points.first.date,
      end = points.isEmpty ? DateTime(2000) : points.last.date;

  final Rect plot;
  final ChartScale scale;
  final List<TimelinePoint> points;
  final DateTime start;
  final DateTime end;

  double x(DateTime date) {
    final span = end.difference(start).inMinutes;
    if (span <= 0) return plot.center.dx;
    return plot.left + plot.width * date.difference(start).inMinutes / span;
  }

  double y(num value) => scale.y(value, plot);

  /// Each point where the hover card keeps clear: its value, or its net
  /// payments before the first declaration.
  List<Offset> get anchors => [
    for (final point in points)
      Offset(x(point.date), y(point.valueMinor ?? point.netPaymentsMinor)),
  ];

  /// The point nearest to [dx] along the time axis.
  int? nearest(double dx) {
    if (points.isEmpty) return null;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final distance = (x(points[i].date) - dx).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// The step-after path through [values] (null breaks nothing: the path
  /// starts at the first non-null one).
  Path step(List<int?> values) {
    final path = Path();
    int? previous;
    for (var i = 0; i < points.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final px = x(points[i].date);
      if (previous == null) {
        path.moveTo(px, y(value));
      } else {
        path
          ..lineTo(px, y(previous))
          ..lineTo(px, y(value));
      }
      previous = value;
    }
    return path;
  }
}

class _PlacementPainter extends CustomPainter {
  _PlacementPainter({
    required this.colors,
    required this.geometry,
    required this.hovered,
    required this.levels,
    required this.ticks,
    required this.labelStyle,
  });

  final AppColors colors;
  final _TimeGeometry geometry;
  final int? hovered;
  final List<String> levels;
  final List<_TimeTick> ticks;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final plot = g.plot;
    if (plot.width <= 0 || plot.height <= 0) return;

    ChartPaints.grid(
      colors,
      canvas,
      size,
      plot,
      [for (final tick in g.scale.ticks) g.y(tick)],
      labels: levels,
      style: labelStyle,
    );
    _paintTimeAxis(canvas, size);

    final points = g.points;
    if (points.isEmpty) return;

    canvas.drawPath(
      g.step([for (final point in points) point.netPaymentsMinor]),
      ChartPaints.stroke(colors.textTertiary)
        ..strokeWidth = AppChart.secondLineStroke,
    );

    final values = [for (final point in points) point.valueMinor];
    final first = values.indexWhere((value) => value != null);
    if (first != -1) {
      final line = g.step(values);
      if (first < points.length - 1) {
        // Held flat between declarations: hatched, not filled.
        final area = Path.from(line)
          ..lineTo(g.x(points.last.date), plot.bottom)
          ..lineTo(g.x(points[first].date), plot.bottom)
          ..close();
        ChartPaints.hatch(canvas, area, colors.accent);
      }
      canvas.drawPath(line, ChartPaints.stroke(colors.accent));
    }

    final declared = [
      for (var i = 0; i < points.length; i++)
        if (points[i].declared) i,
    ];
    final lastDeclared = declared.lastOrNull;
    for (final i in declared) {
      final large = i == lastDeclared || i == hovered;
      if (!large && declared.length > AppChart.dotCeiling) continue;
      ChartPaints.dot(
        colors,
        canvas,
        Offset(g.x(points[i].date), g.y(points[i].valueMinor!)),
        large ? AppChart.currentDotRadius : AppChart.pointDotRadius,
        colors.accent,
      );
    }
    final hover = hovered;
    if (hover != null && hover < points.length && !points[hover].declared) {
      final point = points[hover];
      ChartPaints.dot(
        colors,
        canvas,
        g.anchors[hover],
        AppChart.currentDotRadius,
        point.valueMinor == null ? colors.textTertiary : colors.accent,
      );
    }
  }

  /// The date labels in the 22 px band under the plot, centred on their
  /// date; a label that would overlap the one before it is left out.
  void _paintTimeAxis(Canvas canvas, Size size) {
    final g = geometry;
    final top = size.height - AppChart.axisHeight;
    var rightmost = double.negativeInfinity;
    for (final tick in ticks) {
      final painter = TextPainter(
        text: TextSpan(text: tick.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final left = (g.x(tick.date) - painter.width / 2)
          .clamp(g.plot.left, math.max(g.plot.left, size.width - painter.width))
          .toDouble();
      if (left > rightmost + AppSpacing.sm) {
        painter.paint(
          canvas,
          Offset(left, top + (AppChart.axisHeight - painter.height)),
        );
        rightmost = left + painter.width;
      }
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_PlacementPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.hovered != hovered ||
      oldDelegate.geometry.plot != geometry.plot ||
      !identical(oldDelegate.geometry.points, geometry.points) ||
      oldDelegate.labelStyle != labelStyle;
}
