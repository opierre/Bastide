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

  /// [style] for a [CustomPainter]'s [TextPainter], which does not read the
  /// ambient [TextScaler]: the app's text scale (`00` §3 « Text size ») is
  /// baked into its size, so painted labels grow with every other text.
  /// A [Text] takes [style] as it is.
  static TextStyle painted(BuildContext context, TextStyle style) {
    final size = style.fontSize;
    if (size == null) return style;
    return style.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(size),
    );
  }

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

  /// The zero line, 1 px `lineStrong`, solid, for a series that crosses zero
  /// (`00` §9). Dashes are for annotations only.
  static void zeroLine(
    AppColors colors,
    Canvas canvas,
    Offset from,
    Offset to,
  ) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colors.lineStrong
        ..strokeWidth = AppChart.baselineStroke,
    );
  }

  /// Hatches [region]: what is not yet a fact (the month in progress, a
  /// projected value, a value held flat between two declarations). 45°
  /// lines, 1.5 px on a 5 px pitch, in the mark's own [color], inside a 1 px
  /// outline in that colour (`00` §9). It replaces dashed outlines.
  static void hatch(Canvas canvas, Path region, Color color) {
    final bounds = region.getBounds();
    if (bounds.isEmpty) return;
    final lines = Paint()
      ..color = color
      ..strokeWidth = AppChart.hatchStroke;
    canvas
      ..save()
      ..clipPath(region);
    // Lines rising left to right at 45°, spaced [AppChart.hatchPitch] apart
    // along the horizontal, sweeping the whole bounds.
    for (
      var x = bounds.left - bounds.height;
      x < bounds.right;
      x += AppChart.hatchPitch
    ) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.height, bounds.top),
        lines,
      );
    }
    canvas.restore();
    canvas.drawPath(
      region,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppChart.hatchOutline,
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
