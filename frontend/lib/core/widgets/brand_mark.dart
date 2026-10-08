import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The Bastide logomark: a rampart of three rising steps, each crowned with
/// merlons, cut in ink out of an iris gradient tile.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size and
/// re-tints with the palette. The outlines are the ones in the vector masters
/// (`assets/brand/bastide-mark.svg` and `bastide-mark-small.svg`), on the same
/// 24-unit grid, scaled to [size]. Below [smallSizeThreshold] the mark swaps
/// to the small-size variant — one wider merlon per step — because the main
/// mark's 2-unit notches shrink under a pixel there and the crenellation
/// smears into a plain staircase.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  /// Tile sizes below this draw the small-size glyph.
  static const smallSizeThreshold = 32.0;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.irisGradient,
        borderRadius: BorderRadius.circular(size * _tileRadius / _grid),
      ),
      child: CustomPaint(
        painter: _RampartPainter(
          color: AppColors.irisInk,
          outline: size < smallSizeThreshold ? _smallOutline : _mainOutline,
        ),
      ),
    );
  }
}

/// The masters' design grid and tile corner radius (22 %), in grid units.
const _grid = 24.0;
const _tileRadius = 5.28;

/// `bastide-mark.svg`: three 6-unit steps rising 5 units each inside a 3-unit
/// margin, each topped by two 2 × 2 merlons around a 2-unit notch.
const _mainOutline = [
  (3.0, 21.0),
  (3.0, 14.0),
  (5.0, 14.0),
  (5.0, 16.0),
  (7.0, 16.0),
  (7.0, 14.0),
  (9.0, 14.0),
  (9.0, 9.0),
  (11.0, 9.0),
  (11.0, 11.0),
  (13.0, 11.0),
  (13.0, 9.0),
  (15.0, 9.0),
  (15.0, 4.0),
  (17.0, 4.0),
  (17.0, 6.0),
  (19.0, 6.0),
  (19.0, 4.0),
  (21.0, 4.0),
  (21.0, 21.0),
];

/// `bastide-mark-small.svg`: the same steps, with one 3 × 2.5 merlon at each
/// step's outer end and a 3-unit notch against the next riser.
const _smallOutline = [
  (3.0, 21.0),
  (3.0, 13.5),
  (6.0, 13.5),
  (6.0, 16.0),
  (9.0, 16.0),
  (9.0, 8.5),
  (12.0, 8.5),
  (12.0, 11.0),
  (15.0, 11.0),
  (15.0, 3.5),
  (18.0, 3.5),
  (18.0, 6.0),
  (21.0, 6.0),
  (21.0, 21.0),
];

class _RampartPainter extends CustomPainter {
  const _RampartPainter({required this.color, required this.outline});

  final Color color;
  final List<(double, double)> outline;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid;
    final (startX, startY) = outline.first;
    final path = Path()..moveTo(startX * scale, startY * scale);
    for (final (x, y) in outline.skip(1)) {
      path.lineTo(x * scale, y * scale);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RampartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline;
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
            'Bastide',
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
