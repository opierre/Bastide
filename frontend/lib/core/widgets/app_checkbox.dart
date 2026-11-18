import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';
import 'focus_ring.dart';

/// The checkbox of `docs/design/00-design-system.md` §6: 14 px, radius 4,
/// 1 px `lineStrong`; checked, an `accent` fill with an `onAccent` check.
class AppCheckbox extends StatefulWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// `null` disables the checkbox.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  static const size = 14.0;

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox> {
  bool _focused = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final colors = context.colors;

    return Semantics(
      checked: widget.value,
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
              radius: AppRadii.item,
              child: Container(
                key: const Key('appCheckboxBox'),
                width: AppCheckbox.size,
                height: AppCheckbox.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.value ? colors.accent : colors.field,
                  borderRadius: BorderRadius.circular(AppRadii.item),
                  border: widget.value
                      ? null
                      : Border.all(color: colors.lineStrong),
                ),
                child: widget.value
                    ? Icon(
                        LucideIcons300.check,
                        size: AppCheckbox.size - 2,
                        color: colors.onAccent,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
