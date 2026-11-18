import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A monogram chip: initials on a tinted, rounded-square plate.
///
/// This is the fallback every avatar slot degrades to — an institution with no
/// brand logo, a merchant we don't recognize, a user with no picture — so the
/// UI never renders a broken or empty image. The app never ships brand logos
/// or looks one up on its own; the only picture a merchant chip may show
/// instead is one the user supplied on a rule (see [InstitutionAvatar] and
/// `docs/design/00` §Iconography).
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  /// Whether [name] is a brand the app recognises; any other name renders the
  /// neutral `?` plate. Monograms are always neutral in v2
  /// (`docs/design/00-design-system.md` §7), so this no longer picks a hue.
  static bool isKnown(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _knownBrands.contains(key);
  }

  /// Lowercased, whitespace-collapsed brand names.
  static const _knownBrands = {
    'bnp',
    'bnp paribas',
    'crédit agricole',
    'credit agricole',
    'revolut',
    'caisse locale',
    "caisse locale d'épargne",
    'carrefour',
    'novatech',
    'novatech sarl',
  };

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
    final recognized = isKnown(name);
    final foreground = context.colors.textSecondary;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.hover,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        // An unrecognised institution gets "?" rather than its initials, so the
        // row reads as "we don't know this one" instead of implying a match.
        recognized ? initialsFor(name) : '?',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}

/// The user's own monogram, as shown in the top-bar user pill. Always the iris
/// tint — it identifies the session, not a brand, so the pinned brand hues
/// don't apply.
class UserMonogram extends StatelessWidget {
  const UserMonogram({super.key, required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        MonogramAvatar.initialsFor(name),
        style: TextStyle(
          color: context.colors.accent,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}
