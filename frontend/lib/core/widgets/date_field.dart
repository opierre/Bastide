import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The date shape every form in the app reads and writes — the locale's short
/// numeric form, the same one the transactions feed and the allocation history
/// print, so a date means one thing wherever the user meets it.
DateFormat appDateFormat(String locale) => DateFormat.yMd(locale);

/// A date input with a calendar beside it.
///
/// Typed *and* picked, not one or the other: someone entering a series of
/// allocations knows the date and types it faster than any calendar opens,
/// while « the last Friday of June » is a question only a calendar answers.
/// The field is the single source of truth either way — the picker writes into
/// it, so submit reads one value however it got there.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.firstDate,
    required this.lastDate,
    this.calendarTooltip,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;

  /// The range the calendar offers. Bounds the picker only — a typed date
  /// outside it is the [validator]'s business, not this widget's.
  final DateTime firstDate;
  final DateTime lastDate;

  /// Names the calendar button for assistive tech. Localized text can't be
  /// defaulted here, so callers pass it.
  final String? calendarTooltip;

  final String? Function(String?)? validator;
  final ValueChanged<DateTime>? onChanged;

  Future<void> _pick(BuildContext context) async {
    final locale = Localizations.localeOf(context);
    final current = parseDateInput(controller.text, locale.toString());

    final picked = await showDatePicker(
      context: context,
      // Opens on the date already in the field when there is one, so a calendar
      // reached for after typing lands where the user was rather than back on
      // today.
      initialDate: _clamp(current ?? DateTime.now()),
      firstDate: firstDate,
      lastDate: lastDate,
      locale: locale,
    );
    if (picked == null) return;

    controller.text = appDateFormat(locale.toString()).format(picked);
    onChanged?.call(picked);
  }

  DateTime _clamp(DateTime date) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      inputFormatters: [_DateInputFormatter.forLocale(locale)],
      style: tabularNumberStyle(Theme.of(context).textTheme.bodyLarge!),
      decoration: InputDecoration(
        suffixIcon: IconButton(
          onPressed: () => _pick(context),
          tooltip: calendarTooltip,
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.calendar_today_outlined,
            color: AppColors.textSecondary,
          ),
        ),
        // The 44 px field height the spec pins is measured without an icon in
        // it; left at Material's default the button's own hit box would push
        // the field taller than the one beside it.
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
      validator: validator,
    );
  }
}

/// Keeps the field to the locale's own date spelling: digits, and the
/// separator put in for the user as each section fills.
///
/// A date is one shape, not free text — « 12 mars » or « 2026-03-12 » are only
/// ever a red line under the field later — so the field refuses everything that
/// isn't that shape as it is typed, and types the slashes itself. Whether the
/// completed spelling is a real day is [parseDateInput]'s question, asked on
/// submit.
class _DateInputFormatter extends TextInputFormatter {
  _DateInputFormatter._({
    required this.separator,
    required this.sectionLengths,
  });

  /// Reads the shape out of the locale's own short date pattern — « dd/MM/y »
  /// in French, « M/d/y » in English — so nothing here hard-codes an order or
  /// a slash.
  factory _DateInputFormatter.forLocale(String locale) {
    final pattern = appDateFormat(locale).pattern ?? _fallbackPattern;
    final separator = pattern
        .split('')
        .firstWhere(
          (character) => !_letter.hasMatch(character),
          orElse: () => '/',
        );
    final sections = pattern
        .split(separator)
        // A year takes four digits, a day or a month two.
        .map((section) => section.contains('y') ? 4 : 2)
        .toList();
    return _DateInputFormatter._(
      separator: separator,
      sectionLengths: sections.isEmpty ? const [2, 2, 4] : sections,
    );
  }

  final String separator;
  final List<int> sectionLengths;

  static const _fallbackPattern = 'dd/MM/y';
  static final _letter = RegExp(r'[A-Za-z]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    var text = newValue.text;
    var caret = newValue.selection.end.clamp(0, text.length);

    // Backspacing a separator takes the digit in front of it: the separator was
    // typed by the field, not by the user, and putting it straight back would
    // make the key read as dead.
    if (oldValue.text.length == text.length + 1 &&
        caret > 0 &&
        caret < oldValue.text.length &&
        oldValue.text[caret] == separator) {
      text = text.substring(0, caret - 1) + text.substring(caret);
      caret -= 1;
    }

    final formatted = StringBuffer();
    var caretOffset = 0;
    var section = 0;
    var filled = 0;

    for (var index = 0; index < text.length; index++) {
      if (index == caret) caretOffset = formatted.length;
      final character = text[index];

      if (character == separator) {
        // A separator closes the section being typed — « 5/ » is a month in
        // English. Anywhere else it isn't part of a date.
        final isLast = section == sectionLengths.length - 1;
        if (filled == 0 || isLast) return oldValue;
        formatted.write(separator);
        section++;
        filled = 0;
        continue;
      }

      if (!_isDigit(character)) return oldValue;
      if (filled == sectionLengths[section]) {
        // The section is full: the separator goes in rather than making the
        // user reach for it, and the last section simply stops.
        if (section == sectionLengths.length - 1) return oldValue;
        formatted.write(separator);
        section++;
        filled = 0;
      }
      formatted.write(character);
      filled++;
    }
    if (caret >= text.length) caretOffset = formatted.length;

    final result = formatted.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: caretOffset.clamp(0, result.length),
      ),
    );
  }

  bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

/// Reads a [DateField]'s text, or `null` when it isn't a date in this locale.
///
/// Strict: `DateFormat.parse` would happily read « 32/13/2026 » by rolling it
/// over into the next year, and a form that silently books a date the user did
/// not type is worse than one that says it can't read this.
DateTime? parseDateInput(String raw, String locale) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  try {
    return appDateFormat(locale).parseStrict(text);
  } on FormatException {
    return null;
  }
}
