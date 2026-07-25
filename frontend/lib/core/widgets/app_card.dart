import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The surface every panel builds on: a raised, hairline-bordered plate.
///
/// Replaces Material's [Card] so the whole app shares one radius, one border,
/// and one hover treatment. When [onTap] is set the card lifts its border to
/// the brand accent on pointer hover — desktop affordance without a shadow
/// pop, per the design-system skill's restrained-motion rule.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final highlighted = _interactive && _hovered;

    final card = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: highlighted ? AppColors.surfaceHover : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: highlighted ? AppColors.brandAccentSoft : AppColors.border,
        ),
      ),
      child: widget.child,
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
