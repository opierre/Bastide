import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'labeled_field.dart';

/// A nominal rate typed in percent: digits and one separator only, the figure
/// right-aligned in tabular numerals, « % » as its suffix and « — » as its
/// placeholder (`14-simulateur.md` §Inputs pane, `12-credits.md` Loan form).
///
/// The Simulateur and the loan form type a rate the same way; the text is
/// read as basis points by `parseRateBps` (`core/l10n/loan_display.dart`).
class RateField extends StatelessWidget {
  const RateField({
    super.key,
    required this.controller,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textAlign: TextAlign.right,
      style: tabularNumberStyle(Theme.of(context).textTheme.bodyLarge!),
      decoration: InputDecoration(
        // The dash is a placeholder glyph, not copy (`14` §States, Empty).
        hintText: '—',
        suffixText: '%',
        suffixStyle: fieldSuffixStyle(context),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
