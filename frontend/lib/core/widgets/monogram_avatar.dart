import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The monogram of `docs/design/00-design-system.md` §7: 22 px (32 px
/// "large"), radius 5 (7), `hover` ground, 1 px `line`, initials 10/600
/// (12/600) in `textSecondary`. Always neutral: an institution or a merchant
/// is never told apart by colour.
///
/// « ? » stands for a counterparty the app knows nothing about: a row with
/// no name to draw initials from. Any named row shows its initials.
///
/// It is the fallback every avatar slot degrades to, so the UI never renders
/// a broken or empty image. The app never ships brand logos or looks one up
/// on its own; the only picture a merchant may show instead is one the user
/// supplied on a rule (see [InstitutionAvatar]).
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.name, this.size = small});

  final String name;
  final double size;

  /// The two sizes of `00` §7.
  static const small = 22.0;
  static const large = 32.0;

  /// Whether [size] takes the large monogram's radius and type.
  static bool _isLarge(double size) => size >= large;

  /// The corner radius of a monogram, or of a logo in its place, at [size].
  static double radiusFor(double size) =>
      _isLarge(size) ? AppRadii.monogramLarge : AppRadii.monogramSmall;

  /// One letter per word for the first two words, or the first two letters
  /// of a single word; « ? » when [name] holds no word at all.
  static String initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.hover,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(radiusFor(size)),
      ),
      child: Text(
        initialsFor(name),
        maxLines: 1,
        style: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: _isLarge(size) ? 12 : 10,
          height: 1,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}

/// The user's own monogram, where no preset or picture is chosen: the
/// neutral monogram's ground, border and type on a disc, since avatars are
/// round (`00` §4).
class UserMonogram extends StatelessWidget {
  const UserMonogram({super.key, required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.hover,
        border: Border.all(color: colors.line),
        shape: BoxShape.circle,
      ),
      child: Text(
        MonogramAvatar.initialsFor(name),
        maxLines: 1,
        style: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
          height: 1,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}
