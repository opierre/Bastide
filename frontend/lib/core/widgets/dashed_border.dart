import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Paints a dashed rounded-rectangle outline.
///
/// Flutter has no dashed [BoxBorder], and the spec leans on one to mark
/// "you can't edit this" (read-only currency fields), "nothing here yet"
/// (uncategorized chips) and "drop a file here" (the import DropZone). Doing it
/// once here keeps the dash rhythm identical across all three.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = AppColors.borderDashed,
    this.radius = AppRadii.md,
    this.strokeWidth = 1,
    this.dashLength = 5,
    this.gapLength = 4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Inset by half the stroke so the dashes sit fully inside the bounds
    // instead of being clipped along the outer edge.
    final inset = strokeWidth / 2;
    final outline = Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          math.max(0, size.width - strokeWidth),
          math.max(0, size.height - strokeWidth),
        ),
        Radius.circular(radius),
      ),
    );

    final step = dashLength + gapLength;
    for (final metric in outline.computeMetrics()) {
      // Distribute the remainder across the dashes rather than leaving a short
      // stub where the path closes.
      final count = math.max(1, (metric.length / step).round());
      final actualStep = metric.length / count;
      final actualDash = actualStep * (dashLength / step);
      for (var i = 0; i < count; i++) {
        final start = i * actualStep;
        canvas.drawPath(metric.extractPath(start, start + actualDash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
