import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A deterministic monogram chip: initials on a tinted, rounded-square plate
/// whose hue is derived from [name].
///
/// This is the fallback every avatar slot degrades to — an institution with no
/// brand logo, a merchant we don't recognize, a user with no picture — so the
/// UI never renders a broken or empty image (see the design-system skill).
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  /// Money-sign colors (positive/negative) carry a specific meaning elsewhere
  /// (see the design-system skill) so they're excluded from this palette.
  static const _palette = [
    AppColors.brandAccent,
    AppColors.accentViolet,
    AppColors.info,
    AppColors.warning,
  ];

  /// Sum of code units rather than [String.hashCode]: Dart's string hash is not
  /// guaranteed stable across runs, and an institution that changes color
  /// between launches looks like a bug.
  static Color colorFor(String name) {
    var sum = 0;
    for (final unit in name.trim().toLowerCase().codeUnits) {
      sum += unit;
    }
    return _palette[sum % _palette.length];
  }

  static String initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // A tinted plate reads as part of the dark surface stack; a fully
        // saturated fill would shout louder than the account name next to it.
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
          fontFamily: AppFonts.openSans,
        ),
      ),
    );
  }
}
