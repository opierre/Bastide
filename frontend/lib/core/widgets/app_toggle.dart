import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The spec's switch: a 34×20 track with an explicit 16 px knob, iris when on
/// (`docs/design/00` §Components).
///
/// A widget rather than a themed [Switch]: Material's switch draws a 52×32
/// track with a knob that grows on press, and neither dimension can be styled
/// down to the drawn control.
///
/// The knob takes the near-black ink the spec pins only while the track is
/// iris; on the neutral off-track it lifts to the secondary tone instead. A
/// #0E1030 knob on a #1E2634 track is two darks a point apart — the off state
/// would read as a rendering fault rather than as "off".
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// `null` renders the control non-interactive — used while a toggle's patch
  /// is in flight, so a second tap can't race the first.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.iris : AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: value ? AppColors.irisInk : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
