import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A monogram chip: initials on a tinted, rounded-square plate.
///
/// This is the fallback every avatar slot degrades to — an institution with no
/// brand logo, a merchant we don't recognize, a user with no picture — so the
/// UI never renders a broken or empty image. In Phase 1 it is the *only*
/// treatment: brand logos are deliberately not embedded (see the design-system
/// skill and `docs/design/00` §Iconography).
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  /// Hue for [name], or `null` when the brand isn't one we have a pinned hue
  /// for — the caller renders the neutral `?` plate in that case.
  ///
  /// Pinned rather than hashed: a hue derived from the name would change if a
  /// brand were renamed, and an institution that shifts color between launches
  /// reads as a bug.
  static Color? hueFor(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return MonogramHues.byBrand[key];
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
    final hue = hueFor(name);
    final recognized = hue != null;
    final foreground = hue ?? MonogramHues.unknownForeground;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // A tinted plate reads as part of the dark surface stack; a fully
        // saturated fill would shout louder than the account name next to it.
        color: recognized
            ? foreground.withValues(alpha: 0.16)
            : MonogramHues.unknownBackground,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        // An unrecognised institution gets "?" rather than its initials, so the
        // row reads as "we don't know this one" instead of implying a match.
        recognized ? initialsFor(name) : '?',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
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
        color: AppColors.iris.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        MonogramAvatar.initialsFor(name),
        style: TextStyle(
          color: AppColors.iris,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
          fontFamily: AppFonts.geist,
        ),
      ),
    );
  }
}
