import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Institution/merchant avatar: a deterministic colored monogram chip.
/// No brand-logo source is wired up yet (Phase 1 has no logo field or
/// service — see `docs/design/05-accounts.md`), so this always renders the
/// monogram fallback. It's the single widget a future logo image would slot
/// into, so every card/row that uses it inherits that behavior for free
/// once one is wired up — see the design-system skill's "never a broken
/// image" rule.
class InstitutionAvatar extends StatelessWidget {
  const InstitutionAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  // Money-sign colors (positive/negative) carry a specific meaning elsewhere
  // (see design-system skill) so they're excluded from this palette.
  static const _palette = [AppColors.brandAccent, AppColors.info, AppColors.warning];

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.surfaceBase,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
          fontFamily: AppFonts.openSans,
        ),
      ),
    );
  }
}
