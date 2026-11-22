import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';
import 'labeled_field.dart';

/// The one field a picker filters its list with, in a modal or a popover
/// (`00` §6 « Search field », inside a modal): a full-width 32 px text field
/// (the Text field size) with a leading 14 px `search` icon, a placeholder
/// and no hint. Every type-to-filter field of the app is this widget, so they
/// all share one size (#330).
class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.fieldKey,
    required this.hint,
    required this.onChanged,
  });

  final Key fieldKey;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      child: TextField(
        key: fieldKey,
        autofocus: true,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.sm + AppSpacing.xxs,
              end: AppSpacing.sm,
            ),
            child: Icon(LucideIcons300.search, size: AppSizes.iconSmall),
          ),
          prefixIconConstraints: const BoxConstraints(),
        ),
      ),
    );
  }
}
