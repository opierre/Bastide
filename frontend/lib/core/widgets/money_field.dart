import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'labeled_field.dart';

/// An amount input: digits only, and the currency riding at the end of the
/// field as a unit rather than as a value the form is asking for.
///
/// The same arrangement the account form's opening balance uses — this widget
/// is that pattern made shareable, with the keystroke filter the form fields
/// were missing. Rejecting a letter as it is typed beats accepting it and
/// answering with a red line underneath: the field can only ever hold an
/// amount, so it never has to explain that it wanted one.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.currency,
    this.allowNegative = false,
    this.autofocus = false,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;

  /// The ISO code shown at the end of the field. Empty prints no suffix, for
  /// the moment before the profile has loaded.
  final String currency;

  /// Lets a leading minus through. On for a signed ledger amount — a goal
  /// allocation, where negative is the withdrawal — off for a figure that can
  /// only be positive, like a target.
  final bool allowNegative;

  final bool autofocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final symbols = NumberFormat.decimalPattern(locale).symbols;

    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [
        _MoneyInputFormatter(
          decimalSeparator: symbols.DECIMAL_SEP,
          groupSeparator: symbols.GROUP_SEP,
          allowNegative: allowNegative,
        ),
      ],
      // A form value is a neutral figure, not a movement, so it keeps the
      // primary ink rather than a sign color.
      style: tabularNumberStyle(Theme.of(context).textTheme.bodyLarge!),
      decoration: InputDecoration(
        suffixText: currency.isEmpty ? null : currency,
        suffixStyle: fieldSuffixStyle(context),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// Keeps the field to something that could still become an amount.
///
/// Deliberately permissive about *incomplete* input — a lone « − », a trailing
/// separator — because a formatter that rejects those makes the field
/// impossible to type into forwards. Whether what was typed is a usable amount
/// is [parseMoneyMinor]'s question, asked on submit.
class _MoneyInputFormatter extends TextInputFormatter {
  _MoneyInputFormatter({
    required this.decimalSeparator,
    required this.groupSeparator,
    required this.allowNegative,
  });

  final String decimalSeparator;
  final String groupSeparator;
  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    var decimalSeparators = 0;
    for (var index = 0; index < text.length; index++) {
      final character = text[index];
      if (_isDigit(character)) continue;
      if (character == '-' && allowNegative && index == 0) continue;
      if (_isGroupSeparator(character)) continue;
      if (_isDecimalSeparator(character)) {
        // One decimal point: « 1,50,2 » is not a number in any locale this app
        // runs in.
        if (++decimalSeparators > 1) return oldValue;
        continue;
      }
      return oldValue;
    }
    return newValue;
  }

  bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isDecimalSeparator(String character) => character == decimalSeparator;

  /// The locale's own group separator, plus the spaces a keyboard can actually
  /// produce: French groups with a narrow no-break space, and nobody types one.
  bool _isGroupSeparator(String character) =>
      character == groupSeparator || _typedSpaces.contains(character);

  /// U+0020, U+00A0 and U+202F — the plain space, and the two no-break
  /// spaces `intl` may hand back as a locale's group separator.
  static const _typedSpaces = {' ', '\u00A0', '\u202F'};
}

/// Reads a [MoneyField]'s text as integer minor units, or `null` when it isn't
/// an amount.
///
/// Normalises by hand rather than handing the string to [NumberFormat.parse]:
/// the separators a user *types* are not always the ones a locale *prints* —
/// French groups with U+202F and every keyboard offers a plain space — and a
/// parser that only accepts the printed spelling rejects what the field itself
/// allowed through.
int? parseMoneyMinor(String raw, String locale, {bool allowNegative = false}) {
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  var text = raw.trim();
  if (text.isEmpty) return null;

  for (final separator in {symbols.GROUP_SEP, ' ', '\u00A0', '\u202F'}) {
    text = text.replaceAll(separator, '');
  }
  text = text.replaceAll(symbols.DECIMAL_SEP, '.');

  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return null;
  if (!allowNegative && value < 0) return null;
  return (value * 100).round();
}

/// The inverse, for filling a [MoneyField] from a stored amount.
String formatMoneyInput(int amountMinor, String locale) =>
    NumberFormat.decimalPattern(locale).format(amountMinor / 100);
