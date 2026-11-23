import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/tokens.dart';
import 'modal_parts.dart';
import 'money_field.dart';
import 'rate_field.dart';
import 'term_slider.dart';

/// One field of [LoanTermsFields]: what the feature wires into it.
@immutable
class LoanTermsInput {
  const LoanTermsInput({
    required this.key,
    required this.controller,
    required this.label,
    this.helper,
    this.errorText,
    this.onChanged,
    this.validator,
    this.autofocus = false,
  });

  final Key key;
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
}

/// The terms of a loan as the Simulateur and the loan form both type them
/// (`14-simulateur.md` §Inputs pane, 2–3; `12-credits.md` Loan form): fees
/// beside the borrowed amount, the nominal rate beside the monthly insurance,
/// amounts right-aligned over a « 0,00 » placeholder, then the [term] slider.
/// The Simulateur sets its price and down payment above them as [leading],
/// two more amounts on the same grid.
///
/// The fields come in the feature's controllers and callbacks: the Simulateur
/// pushes each keystroke to its controller, the loan form validates on save.
/// [gutter] and [rowGap] are the grid's spacing where it sits, the Simulateur
/// pane's 12 px or a modal's 16 and 14.
class LoanTermsFields extends StatelessWidget {
  const LoanTermsFields({
    super.key,
    required this.currency,
    required this.fees,
    required this.principal,
    required this.rate,
    required this.insurance,
    required this.term,
    this.leading,
    this.gutter = AppSpacing.smPlus,
    this.rowGap = AppSpacing.smPlus,
  });

  final String currency;
  final LoanTermsInput fees;
  final LoanTermsInput principal;
  final LoanTermsInput rate;
  final LoanTermsInput insurance;
  final TermSlider term;
  final (LoanTermsInput, LoanTermsInput)? leading;
  final double gutter;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    final hint = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 2,
    ).format(0);

    ModalFieldCell money(LoanTermsInput input) => ModalFieldCell(
      label: input.label,
      helper: input.helper,
      errorText: input.errorText,
      input: MoneyField(
        key: input.key,
        controller: input.controller,
        currency: currency,
        autofocus: input.autofocus,
        hintText: hint,
        textAlign: TextAlign.end,
        onChanged: input.onChanged,
        validator: input.validator,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading case (final first, final second)) ...[
          ModalFieldRow(
            gutter: gutter,
            start: money(first),
            end: money(second),
          ),
          SizedBox(height: rowGap),
        ],
        ModalFieldRow(
          gutter: gutter,
          start: money(fees),
          end: money(principal),
        ),
        SizedBox(height: rowGap),
        ModalFieldRow(
          gutter: gutter,
          start: ModalFieldCell(
            label: rate.label,
            helper: rate.helper,
            errorText: rate.errorText,
            input: RateField(
              key: rate.key,
              controller: rate.controller,
              onChanged: rate.onChanged,
              validator: rate.validator,
            ),
          ),
          end: money(insurance),
        ),
        const SizedBox(height: AppSimulator.inputsGap),
        term,
      ],
    );
  }
}
