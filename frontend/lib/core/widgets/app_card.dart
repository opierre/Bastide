import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The surface every panel builds on: a raised, hairline-bordered plate with a
/// faint sheen down its top edge.
///
/// Replaces Material's [Card] so the whole app shares one radius, one border,
/// and one hover treatment. When [onTap] is set the border lifts to iris on
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
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Overrides the raised surface — used by the tinted hero cards (savings
  /// rate, review-queue progress) that the panel specs call for.
  final Color? color;
  final BoxBorder? border;
  final Gradient? gradient;

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
        color: widget.gradient == null
            ? (widget.color ?? AppColors.surfaceRaised)
            : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border:
            widget.border ??
            Border.all(
              color: highlighted
                  ? const Color(0x738B8CF9)
                  : AppColors.borderCard,
            ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          children: [
            // Sized by the padded child, so the sheen's 46% stop is relative to
            // the card's own height rather than a fixed pixel run.
            Padding(padding: widget.padding, child: widget.child),
            const Positioned.fill(child: _Sheen()),
          ],
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

/// A barely-there light wash down the top of the card. At 2.5% it isn't seen as
/// a gradient — it just keeps the top edge from going flat against the base
/// surface, which is what makes the plate read as lifted.
class _Sheen extends StatelessWidget {
  const _Sheen();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x06FFFFFF), Color(0x00FFFFFF)],
            stops: [0.0, 0.46],
          ),
        ),
      ),
    );
  }
}
