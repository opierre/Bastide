import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/recurring_series.dart';

/// The localized name of a cadence — « Mensuel » / "Monthly".
String cadenceLabel(AppLocalizations l10n, Cadence cadence) =>
    switch (cadence) {
      Cadence.weekly => l10n.cadenceWeekly,
      Cadence.monthly => l10n.cadenceMonthly,
      Cadence.quarterly => l10n.cadenceQuarterly,
      Cadence.yearly => l10n.cadenceYearly,
      Cadence.irregular => l10n.cadenceIrregular,
    };

/// « 6 mensuels », « 1 trimestriel » — one cadence's share of the active count.
String cadenceCountLabel(AppLocalizations l10n, Cadence cadence, int count) =>
    switch (cadence) {
      Cadence.weekly => l10n.subscriptionsCadenceWeeklyCount(count),
      Cadence.monthly => l10n.subscriptionsCadenceMonthlyCount(count),
      Cadence.quarterly => l10n.subscriptionsCadenceQuarterlyCount(count),
      Cadence.yearly => l10n.subscriptionsCadenceYearlyCount(count),
      Cadence.irregular => l10n.subscriptionsCadenceIrregularCount(count),
    };

/// Charge dates as the panel prints them, in the locale's short numeric form —
/// the same formatter the transactions feed and the import history use, so a
/// date means the same shape wherever the user meets it.
DateFormat seriesDateFormat(String locale) => DateFormat.yMd(locale);

/// Axis ticks under the price curve, for the charges at [dates]. Day-and-month
/// while the whole history fits inside a year, month-and-year beyond it: a
/// weekly series would otherwise print « mai 2026 » under every tick, and a
/// series running over several years would print a month with no year to
/// place it in. Every charge is labelled, so when two of them share a month in
/// a history longer than a year, the day comes back — otherwise two ticks
/// would name the same month and neither would date its charge.
DateFormat seriesAxisDateFormat(String locale, List<DateTime> dates) {
  if (dates.isEmpty) return DateFormat.MMMd(locale);
  final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
  if (last.difference(first).inDays <= 365) return DateFormat.MMMd(locale);
  final months = {for (final date in dates) date.year * 12 + date.month};
  return months.length == dates.length
      ? DateFormat.yMMM(locale)
      : DateFormat.yMMMd(locale);
}

/// « décembre 2025 » — the month a series has been tracked since.
String seriesMonthLabel(String locale, DateTime date) =>
    DateFormat.yMMMM(locale).format(date);

/// How far off the next charge is, in words: « aujourd'hui », « demain »,
/// « dans 5 jours ».
///
/// Relative rather than a bare date because the card's whole job is to answer
/// "what's about to leave my account" — a date makes the reader do the
/// subtraction, and the exact date is on the caption line right beneath it.
String nextChargeWhen(AppLocalizations l10n, DateTime dueOn, DateTime today) {
  final days = DateTime(
    dueOn.year,
    dueOn.month,
    dueOn.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;

  if (days <= 0) return l10n.subscriptionsNextToday;
  if (days == 1) return l10n.subscriptionsNextTomorrow;
  return l10n.subscriptionsNextInDays(days);
}
