import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Reads « 06/2026 » (or « 6/2026 ») as the first day of that month, or
/// `null` when it doesn't read as one. The same spelling in both locales: a
/// month has no day to put first or last.
DateTime? parseGoalMonth(String raw) {
  final match = RegExp(r'^\s*(\d{1,2})\s*/\s*(\d{4})\s*$').firstMatch(raw);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(2)!), month);
}

/// The inverse, for loading a goal's deadline back into the field.
String formatGoalMonth(DateTime month) =>
    '${month.month.toString().padLeft(2, '0')}/${month.year}';

/// The goal's deadline: a month, typed as « MM/AAAA » or picked from the
/// calendar (`11-goals.md` §Modals, « Échéance (facultative, a month) »).
///
/// The list and the banner only ever print the month (« Juin 2028 »), so the
/// form doesn't ask for a day it would never show. The calendar opens on its
/// year view; whatever day is then picked, only its month is kept.
class GoalMonthField extends StatelessWidget {
  const GoalMonthField({
    super.key,
    required this.controller,
    this.hintText,
    this.calendarTooltip,
    this.validator,
    this.onPicked,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? calendarTooltip;
  final String? Function(String?)? validator;

  /// Called after the calendar wrote a month into the field: a programmatic
  /// change the form's own `onChanged` doesn't see.
  final VoidCallback? onPicked;

  Future<void> _pick(BuildContext context) async {
    final current = parseGoalMonth(controller.text);
    final first = DateTime(2000);
    final last = DateTime(2100, 12, 31);
    var initial = current ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      initialDatePickerMode: DatePickerMode.year,
      locale: Localizations.localeOf(context),
    );
    if (picked == null) return;
    controller.text = formatGoalMonth(picked);
    onPicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(7),
      ],
      style: tabularNumberStyle(Theme.of(context).textTheme.bodyMedium!),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: IconButton(
          key: const Key('goalMonthFieldCalendar'),
          onPressed: () => _pick(context),
          tooltip: calendarTooltip,
          iconSize: AppSizes.iconSmall,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: Icon(
            LucideIcons300.calendar,
            color: context.colors.textTertiary,
          ),
        ),
        // As in DateField: the 32 px field height is measured without an
        // icon in it.
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.formField - 2,
          maxHeight: AppSizes.formField - 2,
        ),
      ),
      validator: validator,
    );
  }
}
