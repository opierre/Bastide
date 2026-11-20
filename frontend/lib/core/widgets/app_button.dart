import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'focus_ring.dart';

/// The four buttons of `docs/design/00-design-system.md` §6, plus the solid
/// destructive fill that only a destructive confirmation modal may use.
enum AppButtonVariant {
  /// `surface` ground, 1 px `lineStrong`, `text` label. The default.
  secondary,

  /// `primary` ground (the ink), `onPrimary` label, no border. One per view.
  primary,

  /// No border, no ground, `textSecondary`. Dismiss and tertiary actions.
  ghost,

  /// Secondary with a `negative` label and a `negative` 45 % border.
  danger,

  /// Solid `negative` fill. Only inside a destructive confirmation modal.
  destructive,
}

/// 28 px, or 36 px for auth screens and modal-wide actions.
enum AppButtonSize {
  regular(AppSizes.button, AppSpacing.sm + AppSpacing.xxs),
  large(AppSizes.buttonLarge, AppSpacing.smPlus + AppSpacing.xxs);

  const AppButtonSize(this.height, this.paddingX);

  final double height;
  final double paddingX;
}

/// A button of the design system: rest, hover, focus, pressed and disabled.
///
/// Hover and pressed change at once (no ripple, `00` §13). Disabled is 45 %
/// opacity and leaves the focus order. Loading swaps the icon for a 14 px
/// spinner and keeps the label, so the button never changes width mid-submit.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.loadingLabel,
    this.expand = false,
    this.iconOnly = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Optional 14 px leading icon.
  final IconData? icon;

  /// Not pressable while loading, but not disabled either: the button keeps
  /// its full colour so the submit reads as in flight.
  final bool isLoading;

  /// Replaces the label while loading, where a caller has a running form of
  /// it (« Import en cours »).
  final String? loadingLabel;

  /// Stretches to the width it is given, label centred.
  final bool expand;

  /// A square button showing only its [icon] (an overflow `ellipsis`); the
  /// [label] stays its accessible name.
  final bool iconOnly;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _disabled => widget.onPressed == null;
  bool get _actionable => !_disabled && !widget.isLoading;

  void _activate() {
    if (_actionable) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (ground, foreground, border) = _paint(colors);
    final label = widget.isLoading
        ? (widget.loadingLabel ?? widget.label)
        : widget.label;

    final square = widget.iconOnly && widget.icon != null;
    final content = square
        ? Icon(widget.icon, size: AppSizes.iconSmall, color: foreground)
        : Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox.square(
                  key: const Key('appButtonSpinner'),
                  dimension: AppSizes.iconSmall,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.xsPlus),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: AppSizes.iconSmall, color: foreground),
                const SizedBox(width: AppSpacing.xsPlus),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
            ],
          );

    final box = Container(
      height: widget.size.height,
      width: square ? widget.size.height : null,
      alignment: square ? Alignment.center : null,
      padding: square
          ? null
          : EdgeInsets.symmetric(horizontal: widget.size.paddingX),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: border == null ? null : Border.all(color: border),
      ),
      child: content,
    );

    return Semantics(
      button: true,
      enabled: _actionable,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: _disabled ? 0.45 : 1,
        child: FocusableActionDetector(
          enabled: !_disabled,
          mouseCursor: _actionable
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _actionable
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: _actionable
                  ? (_) => setState(() => _pressed = false)
                  : null,
              onTap: _actionable ? _activate : null,
              child: FocusRing(
                focused: _focused,
                radius: AppRadii.control,
                child: box,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ground, label and border of the current state. Pressed reads as hover:
  /// the spec names one feedback for both.
  (Color, Color, Color?) _paint(AppColors c) {
    final active = _actionable && (_hovered || _pressed);
    return switch (widget.variant) {
      // Hover moves the ink 8 % away from the page: lighter in dark, darker
      // in light. Extrapolating away from `onPrimary` (the page) does both.
      AppButtonVariant.primary => (
        active ? Color.lerp(c.primary, c.onPrimary, -0.08)! : c.primary,
        c.onPrimary,
        null,
      ),
      AppButtonVariant.secondary => (
        active ? c.hover : c.surface,
        c.text,
        c.lineStrong,
      ),
      AppButtonVariant.ghost => (
        active ? c.hover : Colors.transparent,
        c.textSecondary,
        null,
      ),
      AppButtonVariant.danger => (
        active ? c.hover : c.surface,
        c.negative,
        c.negative.withValues(alpha: 0.45),
      ),
      AppButtonVariant.destructive => (
        active ? Color.lerp(c.negative, c.onPrimary, -0.08)! : c.negative,
        c.onPrimary,
        null,
      ),
    };
  }
}
