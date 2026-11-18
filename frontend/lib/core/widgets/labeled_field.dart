import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// A form control with its label set *above* it rather than floating inside
/// (`docs/design/00-design-system.md` §6): label 12 `textSecondary`, 5 px
/// gap, helper 11 `textTertiary` below, or the error in `negative`.
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: _labelGap),
        child,
        if (errorText != null)
          FieldHelper(text: errorText!, isError: true)
        else if (helper != null)
          FieldHelper(text: helper!),
      ],
    );
  }
}

/// The gap between a field's label and its control (`00` §6).
const _labelGap = 5.0;

/// The 11 px line beneath a field: `textTertiary`, or `negative` for a
/// validation failure, which the field's `negative` border repeats. Failures
/// stay inline rather than becoming a toast, which would vanish before the
/// user has finished reading the form.
class FieldHelper extends StatelessWidget {
  const FieldHelper({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _labelGap),
      child: Text(
        text,
        style: context.textStyles.helper.copyWith(
          color: isError
              ? context.colors.negative
              : context.colors.textTertiary,
        ),
      ),
    );
  }
}

/// The error border, with no inline message.
///
/// For failures that belong to the form as a whole rather than to one field —
/// a rejected credential pair, say — where the reason is already stated once in
/// a banner and repeating it under each input would bury the fix.
InputDecoration errorFieldDecoration(BuildContext context) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.control),
    borderSide: BorderSide(color: context.colors.negative),
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
).textTheme.bodyMedium!.copyWith(color: context.colors.textSecondary);

/// A value the user is shown but cannot change (`00` §6): no border, the
/// value in `textSecondary` after a 14 px `lock`. The permanence itself is
/// carried by the caller's [LabeledField.helper] copy.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    super.key,
    required this.value,
    this.suffix,
    this.height = AppSizes.formField,
  });

  final String value;

  /// Unit the value is expressed in, a currency code chiefly, set at the
  /// field's end in the secondary tone.
  final String? suffix;

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Icon(
            LucideIcons300.lock,
            size: AppSizes.iconSmall,
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xsPlus),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(suffix!, style: fieldSuffixStyle(context)),
          ],
        ],
      ),
    );
  }
}

/// Paints a text field's focus ring (`00` §6): the `accent` border comes from
/// the input theme, and this adds the 3 px `accentSoft` ring around it, which
/// [InputBorder] cannot draw.
class FocusGlow extends StatefulWidget {
  const FocusGlow({
    super.key,
    required this.child,
    this.radius = AppRadii.control,
  });

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
              ? [
                  BoxShadow(
                    color: context.colors.accentSoft,
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
