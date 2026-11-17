import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The shared chart frame ([AppChart]) as paint calls, so every chart draws its
/// gridlines, line, area, dots, dashes and labels the same way
/// (`docs/design/00-design-system.md` §9). The colours come from the active
/// theme, which a painter receives as [AppColors] from its widget.
///
/// A chart still owns its geometry — where its points and ticks fall — but not
/// how they look.
abstract final class ChartPaints {
  /// Every axis label, value and time alike: 11 px `textTertiary`, tabular
  /// figures so a column of amounts holds its alignment.
  static TextStyle labelStyle(BuildContext context) => tabularNumberStyle(
    Theme.of(context).textTheme.labelSmall!,
  ).copyWith(fontWeight: FontWeight.w400, color: context.colors.textTertiary);

  /// The series line in [color].
  static Paint stroke(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = AppChart.lineStroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// The area under a line in [color].
  static Paint area(Color color) =>
      Paint()..color = color.withValues(alpha: AppChart.areaAlpha);

  /// The area under zero, for a series that crosses it.
  static Paint negativeArea(AppColors colors) =>
      Paint()
        ..color = colors.negative.withValues(alpha: AppChart.negativeAreaAlpha);

  /// One hairline per entry of [ys], from the plot's left edge to the chart's
  /// right one, each named by the label at the same index of [labels] in the
  /// value gutter, ending [AppChart.labelGap] short of the plot. [labels] may
  /// be empty (unlabelled gridlines) or shorter than [ys].
  static void grid(
    AppColors colors,
    Canvas canvas,
    Size size,
    Rect plot,
    List<double> ys, {
    List<String> labels = const [],
    TextStyle? style,
  }) {
    final paint = Paint()
      ..color = colors.line
      ..strokeWidth = AppChart.gridStroke;
    for (var i = 0; i < ys.length; i++) {
      canvas.drawLine(
        Offset(plot.left, ys[i]),
        Offset(size.width, ys[i]),
        paint,
      );
      if (i >= labels.length || style == null) continue;
      final label = TextPainter(
        text: TextSpan(text: labels[i], style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      label.paint(
        canvas,
        Offset(
          plot.left - AppChart.labelGap - label.width,
          ys[i] - label.height / 2,
        ),
      );
      label.dispose();
    }
  }

  /// A point's dot: a [radius] disc in [color] on a `bg` ring, so it
  /// sits on the line. [AppChart.pointDotRadius] for every point,
  /// [AppChart.currentDotRadius] for the current and the hovered one.
  static void dot(
    AppColors colors,
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    canvas
      ..drawCircle(
        center,
        radius + AppChart.dotRing,
        Paint()..color = colors.bg,
      )
      ..drawCircle(center, radius, Paint()..color = color);
  }

  /// A hollow dot, for a point still moving (the open month): the same ring,
  /// then an outline in [color] instead of a disc.
  static void hollowDot(
    AppColors colors,
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    canvas
      ..drawCircle(
        center,
        radius + AppChart.dotRing,
        Paint()..color = colors.bg,
      )
      ..drawCircle(
        center,
        radius - AppChart.dotRing / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppChart.dotRing,
      );
  }

  /// [source] cut into [AppChart.dash] dashes with [AppChart.dashGap] gaps.
  static Path dashed(Path source) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      for (
        var start = 0.0;
        start < metric.length;
        start += AppChart.dash + AppChart.dashGap
      ) {
        dashed.addPath(
          metric.extractPath(start, start + AppChart.dash),
          Offset.zero,
        );
      }
    }
    return dashed;
  }

  /// A dashed reference line from [from] to [to] — the zero baseline, or an
  /// annotation's vertical — in [color], `lineStrong` by default.
  static void baseline(
    AppColors colors,
    Canvas canvas,
    Offset from,
    Offset to, {
    Color? color,
  }) {
    canvas.drawPath(
      dashed(
        Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy),
      ),
      Paint()
        ..color = color ?? colors.lineStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppChart.baselineStroke,
    );
  }
}
