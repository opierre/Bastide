import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// How the tomettes fade out (`docs/design/18-brand.md` §2).
enum TomettesFade {
  /// Full strength everywhere: the goal banner and the À propos header.
  none,

  /// Clear from the centre to 22 % of the radius, full at 75 %: the auth
  /// screens, the startup screen and the empty states, so the pattern never
  /// sits behind the text.
  radial,

  /// Clear at the top and bottom, full from 35 % to 75 % of the height: the
  /// sidebar's empty stretch.
  vertical,
}

/// The tomettes texture (`docs/design/00-design-system.md` §12), a
/// hexagonal line pattern drawn in the theme's [AppColors.tomette].
///
/// It fills its parent, so place it under the content in a [Stack]:
/// `Positioned.fill(child: Tomettes())`. It is decoration only: it ignores
/// the pointer and is hidden from semantics.
///
/// Allowed in five places only (§12): the auth screens, an empty state, the
/// sidebar's empty stretch, a goal banner without an image and the À propos
/// header, plus the startup screen.
class Tomettes extends StatelessWidget {
  const Tomettes({super.key, this.fade = TomettesFade.radial});

  final TomettesFade fade;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: TomettesPainter(color: context.colors.tomette, fade: fade),
          ),
        ),
      ),
    );
  }
}

/// Tiles the tomettes path from the top-left corner at a 1 px stroke in
/// [color], then masks it by [fade].
class TomettesPainter extends CustomPainter {
  const TomettesPainter({required this.color, this.fade = TomettesFade.none});

  /// The tile, in logical pixels.
  static const tileSize = Size(24.25, 42);

  final Color color;
  final TomettesFade fade;

  /// One tile's strokes: `M0 7 12.125 0l12.125 7M0 7v14M24.25 7v14`
  /// `M0 21l12.125 7 12.125-7M12.125 28v14`.
  static Path _tile(double dx, double dy) => Path()
    ..moveTo(dx, dy + 7)
    ..lineTo(dx + 12.125, dy)
    ..lineTo(dx + 24.25, dy + 7)
    ..moveTo(dx, dy + 7)
    ..lineTo(dx, dy + 21)
    ..moveTo(dx + 24.25, dy + 7)
    ..lineTo(dx + 24.25, dy + 21)
    ..moveTo(dx, dy + 21)
    ..lineTo(dx + 12.125, dy + 28)
    ..lineTo(dx + 24.25, dy + 21)
    ..moveTo(dx + 12.125, dy + 28)
    ..lineTo(dx + 12.125, dy + 42);

  /// The pattern covering [size], whole tiles from the origin.
  static Path patternFor(Size size) {
    final path = Path();
    for (var y = 0.0; y < size.height; y += tileSize.height) {
      for (var x = 0.0; x < size.width; x += tileSize.width) {
        path.addPath(_tile(x, y), Offset.zero);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    if (fade == TomettesFade.none) {
      canvas
        ..save()
        ..clipRect(bounds)
        ..drawPath(patternFor(size), stroke)
        ..restore();
      return;
    }

    canvas
      ..saveLayer(bounds, Paint())
      ..clipRect(bounds)
      ..drawPath(patternFor(size), stroke)
      ..drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _mask(size),
      )
      ..restore();
  }

  /// Opaque where the pattern shows, clear where it fades. Only the alpha
  /// matters under [BlendMode.dstIn].
  ui.Shader _mask(Size size) {
    final shown = color.withValues(alpha: 1);
    final hidden = color.withValues(alpha: 0);
    switch (fade) {
      case TomettesFade.vertical:
        return ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [hidden, shown, shown, hidden],
          [0, 0.35, 0.75, 1],
        );
      case TomettesFade.radial || TomettesFade.none:
        // CSS `radial-gradient(ellipse at center, …)`: an ellipse through the
        // corners, with the box's proportions.
        final centre = size.center(Offset.zero);
        final rx = size.width / 2 * math.sqrt2;
        final squash = size.height / size.width;
        final matrix = Matrix4.identity()
          ..translateByDouble(centre.dx, centre.dy, 0, 1)
          ..scaleByDouble(1, squash, 1, 1)
          ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
        return ui.Gradient.radial(
          centre,
          rx,
          [hidden, shown],
          [0.22, 0.75],
          TileMode.clamp,
          matrix.storage,
        );
    }
  }

  @override
  bool shouldRepaint(TomettesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fade != fade;
}
