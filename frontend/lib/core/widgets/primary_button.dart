import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The iris-gradient primary button.
///
/// This is a widget rather than a [ButtonStyle] because Material's button
/// styling takes a flat `backgroundColor` and cannot paint a gradient or the
/// spec's outer glow. Everything else — secondary, danger, ghost — is expressible
/// as a theme style and stays on [OutlinedButton] / [TextButton].
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 38,
    this.expand = false,
    this.loadingLabel,
  });

  /// The 46px full-width variant used by the auth screens.
  const PrimaryButton.submit({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  }) : icon = null,
       height = 46,
       expand = true;

  final String label;

  /// `null` disables the button — it drops to the flat `#1E2634` / disabled-text
  /// treatment and loses the glow.
  final VoidCallback? onPressed;

  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  /// Shown beside the spinner while loading. The button keeps its label rather
  /// than shrinking to a bare spinner, so the row never reflows mid-submit.
  final String? loadingLabel;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // A loading button is not pressable, but it is not *disabled* either — it
    // keeps the gradient so the submit still reads as in-flight.
    final enabled = widget.onPressed != null && !widget.isLoading;
    final muted = widget.onPressed == null;
    final label = widget.isLoading
        ? (widget.loadingLabel ?? widget.label)
        : widget.label;
    final foreground = muted ? AppColors.textDisabled : AppColors.irisInk;

    final button = Container(
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.height * 0.42),
      decoration: BoxDecoration(
        gradient: muted ? null : AppColors.irisGradient,
        color: muted ? AppColors.surfaceHover : null,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: muted || !_hovered ? null : AppColors.irisGlow,
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading) ...[
            SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: AppChrome.navIconSize, color: foreground),
            const SizedBox(width: AppSpacing.sm - 1),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: button,
        ),
      ),
    );
  }
}
