import 'package:flutter/material.dart';
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
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
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
