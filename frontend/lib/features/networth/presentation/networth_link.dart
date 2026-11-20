import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/focus_ring.dart';

/// A link (`00` §6): `accent`, 12 px, underlined on hover, focusable. No
/// arrow glyph. « Historique déclaré » and the no-property « Nouveau bien ».
class NetworthLink extends StatefulWidget {
  const NetworthLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<NetworthLink> createState() => _NetworthLinkState();
}

class _NetworthLinkState extends State<NetworthLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.accent,
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
