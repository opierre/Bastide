import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/focus_ring.dart';

/// A 12 px link of the signed-out column (`00` §6, Link): `accent`,
/// underlined on hover, with the shared focus outline. Reachable with the
/// keyboard and activated with `Enter` or `Space`.
class AuthLink extends StatefulWidget {
  const AuthLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<AuthLink> createState() => _AuthLinkState();
}

class _AuthLinkState extends State<AuthLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: accent,
      decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
      decorationColor: accent,
    );

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        link: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: FocusRing(
            focused: _focused,
            radius: AppRadii.item,
            child: Text(widget.label, style: style),
          ),
        ),
      ),
    );
  }
}
