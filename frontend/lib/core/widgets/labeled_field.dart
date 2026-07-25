import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A form control with its label set *above* it rather than floating inside.
///
/// Material's floating label has to shrink into the field's border notch, which
/// truncates badly once French labels run 15–20% longer than their English
/// counterparts. An external label has room, keeps a consistent baseline down
/// the form, and lets fields use their hint slot for an example value.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;

  /// Optional note aligned to the right of the label (e.g. "optional").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        child,
      ],
    );
  }
}
