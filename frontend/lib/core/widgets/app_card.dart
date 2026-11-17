import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The surface every panel builds on: a hairline-bordered plate.
///
/// Replaces Material's [Card] so the whole app shares one radius, one border,
/// and one hover treatment. When [onTap] is set the border strengthens on
/// pointer hover — the fill deliberately does *not* change, so a hovered card
/// doesn't read as selected.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color,
    this.border,
    this.alignment = AlignmentDirectional.topStart,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Overrides the raised surface — used by the tinted hero cards (savings
  /// rate, review-queue progress) that the panel specs call for.
  final Color? color;
  final BoxBorder? border;

  /// How [child] sits inside the card once it's shorter than the space a
  /// stretched sibling row gives it (see the dashboard's `IntrinsicHeight` +
  /// `CrossAxisAlignment.stretch` grid). Defaults to the top-start the
  /// internal [Stack] would use anyway, so every existing card keeps its
  /// current look.
  final AlignmentGeometry alignment;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final highlighted = _interactive && _hovered;

    // Hover is an instant border swap, not an animation: the spec allows only
    // the spinner and skeleton keyframes.
    final card = Container(
      decoration: BoxDecoration(
        color: widget.color ?? context.colors.bg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border:
            widget.border ??
            Border.all(
              color: highlighted
                  ? context.colors.lineStrong
                  : context.colors.line,
            ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          alignment: widget.alignment,
          children: [Padding(padding: widget.padding, child: widget.child)],
        ),
      ),
    );

    if (!_interactive) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}
