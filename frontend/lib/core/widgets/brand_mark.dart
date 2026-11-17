import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The Bastide mark « Plan » (`docs/design/18-brand.md` §1): the grid plan of
/// a bastide, nine squares on a tile, the central square in the accent.
///
/// Painted from tokens rather than loaded from `assets/brand/`, so it follows
/// the theme: the tile is [AppColors.primary], the eight squares
/// [AppColors.onPrimary] and the centre [AppColors.accent]. Every size draws
/// the same geometry, down to the 16 px minimum.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 20});

  /// The smallest size the spec allows.
  static const minSize = 16.0;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: PlanMarkPainter(
          tile: colors.primary,
          glyph: colors.onPrimary,
          accent: colors.accent,
        ),
      ),
    );
  }
}

/// Paints the « Plan » geometry, on its 24-unit grid, scaled to the canvas.
class PlanMarkPainter extends CustomPainter {
  const PlanMarkPainter({
    required this.tile,
    required this.glyph,
    required this.accent,
  });

  /// The design grid, the tile's corner radius (22 %), the squares' side and
  /// corner radius, and their origins on each axis (margin 4.5, gap 1.5).
  static const grid = 24.0;
  static const tileRadius = 5.3;
  static const cell = 4.0;
  static const cellRadius = 0.8;
  static const cellOrigins = [4.5, 10.0, 15.5];

  final Color tile;
  final Color glyph;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / grid;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size.square(grid * unit),
        Radius.circular(tileRadius * unit),
      ),
      Paint()..color = tile,
    );
    final glyphPaint = Paint()..color = glyph;
    final accentPaint = Paint()..color = accent;
    for (final (row, y) in cellOrigins.indexed) {
      for (final (column, x) in cellOrigins.indexed) {
        final centre = row == 1 && column == 1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * unit, y * unit, cell * unit, cell * unit),
            Radius.circular(cellRadius * unit),
          ),
          centre ? accentPaint : glyphPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PlanMarkPainter oldDelegate) =>
      oldDelegate.tile != tile ||
      oldDelegate.glyph != glyph ||
      oldDelegate.accent != accent;
}

/// The mark plus « Bastide » in Geist 600 at −0.02 em, with an 8-unit gap.
///
/// Sizes from `18-brand.md` §1: sidebar 20/14, auth 20/16, À propos 44/16,
/// splash and startup 64/26. The startup screen stacks a 64 px [BrandMark]
/// over a [BrandName] instead.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 20, this.nameSize = 14});

  const BrandLockup.sidebar({super.key}) : markSize = 20, nameSize = 14;

  /// Login and the other signed-out screens.
  const BrandLockup.login({super.key}) : markSize = 20, nameSize = 16;

  /// Registration uses the same auth lockup as login.
  const BrandLockup.register({super.key}) : markSize = 20, nameSize = 16;

  const BrandLockup.about({super.key}) : markSize = 44, nameSize = 16;

  final double markSize;
  final double nameSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 8 / PlanMarkPainter.grid),
        Flexible(child: BrandName(size: nameSize)),
      ],
    );
  }
}

/// « Bastide » set as the brand name: Geist 600, tracking −0.02 em.
class BrandName extends StatelessWidget {
  const BrandName({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      // The product name is a proper noun, so it is intentionally not
      // localized (see the i18n-l10n skill).
      'Bastide',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.geist,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * size,
        height: 1.2,
        color: context.colors.text,
      ),
    );
  }
}
