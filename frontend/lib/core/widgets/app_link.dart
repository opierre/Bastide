import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'focus_ring.dart';

/// A link (`docs/design/00-design-system.md` §6, Link): `accent`, 12 or
/// 13 px, underlined on hover, focusable and activated with `Enter` or
/// `Space`. No arrow glyph in the label. The right side of a section
/// heading, « Voir tout », « Effacer les filtres », a file name.
class AppLink extends StatefulWidget {
  const AppLink({
    super.key,
    required this.label,
    required this.onTap,
    this.small = true,
    this.mono = false,
  });

  final String label;
  final VoidCallback onTap;

  /// 12 px; 13 px when `false`.
  final bool small;

  /// Geist Mono, for a file name (`00` §3).
  final bool mono;

  @override
  State<AppLink> createState() => _AppLinkState();
}

class _AppLinkState extends State<AppLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final textTheme = Theme.of(context).textTheme;
    final base = widget.small ? textTheme.bodySmall! : textTheme.bodyMedium!;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.item,
          child: Semantics(
            link: true,
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tabularNumberStyle(base).copyWith(
                color: accent,
                fontFamily: widget.mono ? AppFonts.mono : null,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
