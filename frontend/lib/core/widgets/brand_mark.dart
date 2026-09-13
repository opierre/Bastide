import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The FinStride logomark: three ascending bars cut out of an iris gradient
/// plate. Drawn rather than shipped as an asset so it stays crisp at any size
/// and re-tints with the palette.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.irisGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: CustomPaint(
        painter: const _AscendingBarsPainter(color: AppColors.irisInk),
      ),
    );
  }
}

class _AscendingBarsPainter extends CustomPainter {
  const _AscendingBarsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    final barWidth = w * 0.14;
    final radius = Radius.circular(barWidth * 0.4);
    // Bars share a baseline and grow to the right — the "stride" is the climb,
    // so the heights are what carries the meaning, not a separate arrow glyph.
    const heights = [0.26, 0.42, 0.58];
    final baseline = h * 0.74;
    final firstLeft = w * 0.26;
    final gap = barWidth * 0.62;

    for (var i = 0; i < heights.length; i++) {
      final left = firstLeft + i * (barWidth + gap);
      final top = baseline - h * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, left + barWidth, baseline),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AscendingBarsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Logomark plus the wordmark, as used in the sidebar header and on the auth
/// screens. The three call sites use different sizes (sidebar 30/17, login
/// 40/26, register 34/22), so both are parameters rather than fixed.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 30, this.wordmarkSize = 17});

  const BrandLockup.sidebar({super.key}) : markSize = 30, wordmarkSize = 17;

  const BrandLockup.login({super.key}) : markSize = 40, wordmarkSize = 26;

  const BrandLockup.register({super.key}) : markSize = 34, wordmarkSize = 22;

  final double markSize;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.3),
        Flexible(
          child: Text(
            // The product name is a proper noun, so it is intentionally not
            // localized (see the i18n-l10n skill).
            'FinStride',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.spaceGrotesk,
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
