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
    this.onChanged,
    this.hintText,
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

  /// Fires on user edits only, never when [controller] is written by code.
  final ValueChanged<String>? onChanged;

  /// Placeholder shown while the field is empty — « 0,00 » on a form that
  /// opens blank rather than on a value.
  final String? hintText;

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
        hintText: hintText,
        suffixText: currency.isEmpty ? null : currency,
        suffixStyle: fieldSuffixStyle(context),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
    );
  }
}

/// Keeps the field to something that could still become an amount, and groups
/// its thousands as it is typed.
///
/// The grouping is the locale's own — the narrow no-break space French prints,
/// the comma English does — so a figure being typed reads the way the same
/// figure reads everywhere else in the app rather than as a bare run of digits.
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
    if (newValue.text.isEmpty) return newValue;

    var text = newValue.text;
    var caret = newValue.selection.end.clamp(0, text.length);

    // Backspacing a group separator takes the digit in front of it. The
    // separator is not something the user typed, so removing it on its own
    // would leave the field unchanged once it is regrouped, and the key would
    // read as dead.
    if (oldValue.text.length == text.length + 1 &&
        caret > 0 &&
        caret < oldValue.text.length &&
        oldValue.text[caret] == groupSeparator) {
      text = text.substring(0, caret - 1) + text.substring(caret);
      caret -= 1;
    }

    // What the user typed, with the grouping taken back out: it is rewritten
    // from scratch below, so the separators already in the field would only
    // get in the way of counting.
    final typed = StringBuffer();
    var kept = 0;
    var keptBeforeCaret = 0;
    var decimalSeparators = 0;

    for (var index = 0; index < text.length; index++) {
      if (index == caret) keptBeforeCaret = kept;
      final character = text[index];
      if (_isGroupSeparator(character)) continue;
      if (_isDigit(character)) {
        // Always welcome.
      } else if (character == '-' && allowNegative && kept == 0) {
        // A sign, and only in front: « 1-5 » is not an amount.
      } else if (_isDecimalSeparator(character)) {
        // One decimal point: « 1,50,2 » is not a number in any locale this app
        // runs in.
        if (++decimalSeparators > 1) return oldValue;
      } else {
        return oldValue;
      }
      typed.write(character);
      kept++;
    }
    if (caret >= text.length) keptBeforeCaret = kept;

    final formatted = _group(typed.toString());
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _caretAfter(formatted, keptBeforeCaret),
      ),
    );
  }

  /// Rewrites the integer part in threes, leaving the sign and everything from
  /// the decimal separator on exactly as typed.
  String _group(String typed) {
    final sign = typed.startsWith('-') ? '-' : '';
    final body = typed.substring(sign.length);
    final decimalIndex = body.indexOf(decimalSeparator);
    final integer = decimalIndex == -1 ? body : body.substring(0, decimalIndex);
    final fraction = decimalIndex == -1 ? '' : body.substring(decimalIndex);

    final grouped = StringBuffer();
    for (var index = 0; index < integer.length; index++) {
      if (index > 0 && (integer.length - index) % 3 == 0) {
        grouped.write(groupSeparator);
      }
      grouped.write(integer[index]);
    }
    return '$sign$grouped$fraction';
  }

  /// Where the caret sits in the grouped text, counted in the characters the
  /// user actually typed — the separators this formatter inserted are not
  /// positions they can be measured from.
  int _caretAfter(String formatted, int typedBeforeCaret) {
    var typed = 0;
    for (var index = 0; index < formatted.length; index++) {
      if (typed == typedBeforeCaret) return index;
      if (formatted[index] != groupSeparator) typed++;
    }
    return formatted.length;
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
