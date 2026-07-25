import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The FinStride logomark: an ascending stride line on a brand gradient plate.
/// Drawn rather than shipped as an asset so it stays crisp at any size and
/// re-tints with the palette.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandAccent, AppColors.brandAccentDeep],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: CustomPaint(painter: _StridePainter(color: AppColors.surfaceSunken)),
    );
  }
}

class _StridePainter extends CustomPainter {
  const _StridePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Trend line: down-step then a decisive climb to the top right.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.66)
        ..lineTo(w * 0.43, h * 0.47)
        ..lineTo(w * 0.55, h * 0.58)
        ..lineTo(w * 0.78, h * 0.32),
      paint,
    );

    // Arrow head on the climbing end.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.60, h * 0.30)
        ..lineTo(w * 0.78, h * 0.30)
        ..lineTo(w * 0.78, h * 0.48),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StridePainter oldDelegate) => oldDelegate.color != color;
}

/// Logomark plus the wordmark, as used in the sidebar header and on the auth
/// screens.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 34, this.wordmarkSize = 18});

  final double markSize;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Flexible(
          child: Text(
            // The product name is a proper noun, so it is intentionally not
            // localized (see the i18n-l10n skill).
            'FinStride',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.openSans,
              fontSize: wordmarkSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
