import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The focus outline every control shares (`docs/design/00-design-system.md`
/// §6): 2 px `accent`, 1 px clear of the control's edge, following its
/// [radius]. Text fields take an `accent` border and an `accentSoft` ring
/// instead (see `FocusGlow`).
///
/// Painted over the child and outside its box, so showing it never moves the
/// layout.
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.focused,
    required this.radius,
    required this.child,
  });

  final bool focused;
  final double radius;
  final Widget child;

  /// Outline width and its gap from the control.
  static const width = 2.0;
  static const offset = 1.0;

  @override
  Widget build(BuildContext context) {
    if (!focused) return child;
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(
        color: context.colors.accent,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke is centred on its path, so the path sits half a stroke past
    // the gap.
    const inflate = FocusRing.offset + FocusRing.width / 2;
    final rect = (Offset.zero & size).inflate(inflate);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius + inflate)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = FocusRing.width,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
