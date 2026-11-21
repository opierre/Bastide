import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/focus_ring.dart';

/// A link (`00` §6): `accent`, 13 or 12 px, underlined on hover, focusable.
/// No arrow glyph. « Voir la série », « Effacer les filtres », « Paramètres »,
/// the import's file name.
class TransactionsLink extends StatefulWidget {
  const TransactionsLink({
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
  State<TransactionsLink> createState() => _TransactionsLinkState();
}

class _TransactionsLinkState extends State<TransactionsLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final base = widget.small ? textTheme.bodySmall : textTheme.bodyMedium;

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
              style: base?.copyWith(
                color: colors.accent,
                fontFamily: widget.mono ? AppFonts.mono : null,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: colors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
