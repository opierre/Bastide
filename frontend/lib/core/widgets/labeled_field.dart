import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'dashed_border.dart';

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
    this.helper,
    this.errorText,
  });

  final String label;
  final Widget child;

  /// Optional note aligned to the right of the label (e.g. "optional").
  final Widget? trailing;

  /// Guidance shown beneath the field in the neutral tone.
  final String? helper;

  /// Validation failure shown beneath the field. Takes precedence over
  /// [helper] — showing both would bury the thing the user has to fix.
  final String? errorText;

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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        child,
        if (errorText != null)
          FieldHelper(text: errorText!, isError: true)
        else if (helper != null)
          FieldHelper(text: helper!),
      ],
    );
  }
}

/// The 11.5px line beneath a field. Validation failures get a leading red dot
/// as well as red text, so the failure isn't carried by color alone — and they
/// stay inline rather than becoming a toast, which would vanish before the user
/// has finished reading the form.
class FieldHelper extends StatelessWidget {
  const FieldHelper({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.negative,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.helper.copyWith(
                color: isError ? AppColors.negative : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The error border, with no inline message.
///
/// For failures that belong to the form as a whole rather than to one field —
/// a rejected credential pair, say — where the reason is already stated once in
/// a banner and repeating it under each input would bury the fix.
InputDecoration errorFieldDecoration() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: const BorderSide(color: Color(0x8CFF5C6C)),
  );
  return InputDecoration(enabledBorder: border, focusedBorder: border);
}

/// The tone a unit takes at the end of a field — a currency code beside an
/// amount, chiefly. Secondary rather than primary so the figure keeps the
/// weight: the code labels the number, it isn't part of it.
///
/// Shared by [ReadOnlyField.suffix] and the `suffixText` of an editable field,
/// so an amount reads the same whether or not the user can change it.
TextStyle fieldSuffixStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodyLarge!.copyWith(color: AppColors.textSecondary);

/// A value the user is shown but cannot change.
///
/// Rendered as a dashed plate with a lock glyph rather than a disabled input:
/// a greyed-out field reads as "not available yet", whereas this reads as
/// "settled, and deliberately so". The permanence itself is carried by the
/// caller's [LabeledField.helper] copy.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    super.key,
    required this.value,
    this.suffix,
    this.height = 44,
  });

  final String value;

  /// Unit the value is expressed in — a currency code, chiefly. Set in the
  /// secondary tone at the field's end so it reads as a label on the figure
  /// rather than as part of it.
  final String? suffix;

  final double height;

  @override
  Widget build(BuildContext context) {
    return DashedBorder(
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceField,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(suffix!, style: fieldSuffixStyle(context)),
            ],
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the spec's focus ring: the 1px iris border comes from the input
/// theme, and this adds the `0 0 0 3px rgba(139,140,249,.15)` halo around it,
/// which [InputBorder] cannot draw.
class FocusGlow extends StatefulWidget {
  const FocusGlow({super.key, required this.child, this.radius = AppRadii.md});

  final Widget child;
  final double radius;

  @override
  State<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<FocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x268B8CF9),
                    spreadRadius: 3,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
