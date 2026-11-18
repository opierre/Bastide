import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'focus_ring.dart';

/// The toggle of `docs/design/00-design-system.md` §6: 28 × 16, radius 8,
/// `lineStrong` off and `accent` on, with a 12 px knob in `bg`.
///
/// A widget rather than a themed [Switch]: Material's switch draws a 52×32
/// track with a knob that grows on press, and neither can be styled down to
/// the drawn control.
class AppToggle extends StatefulWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// `null` disables the toggle, used while its patch is in flight so a
  /// second tap can't race the first.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  static const width = 28.0;
  static const height = 16.0;
  static const knob = 12.0;

  @override
  State<AppToggle> createState() => _AppToggleState();
}

class _AppToggleState extends State<AppToggle> {
  bool _focused = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final colors = context.colors;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: enabled ? _toggle : null,
            child: FocusRing(
              focused: _focused,
              radius: AppRadii.full,
              child: Container(
                key: const Key('appToggleTrack'),
                width: AppToggle.width,
                height: AppToggle.height,
                padding: const EdgeInsets.all(AppSpacing.xxs),
                alignment: widget.value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: widget.value ? colors.accent : colors.lineStrong,
                  borderRadius: BorderRadius.circular(AppToggle.height / 2),
                ),
                child: Container(
                  width: AppToggle.knob,
                  height: AppToggle.knob,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
