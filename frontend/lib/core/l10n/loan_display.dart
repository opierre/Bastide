import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// A basis-point figure printed as the locale's percent — « 30,8 % », « 3.25% ».
///
/// Display formatting only: the value is the API's, and the division is the
/// unit change a percent sign implies, not a computation about the loan.
String formatBps(int bps, String locale, {int digits = 1}) {
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = digits
    ..maximumFractionDigits = digits;
  return format.format(bps / 10000);
}

/// A nominal rate, always to the hundredth the user typed it in.
String formatRate(int bps, String locale) => formatBps(bps, locale, digits: 2);

/// Reads a typed percent as basis points — « 3,45 » → 345.
///
/// The one place a rate changes unit (rates are bps). Done on the digits
/// rather than through a double, so 3,45 can never come out as 344. Accepts a
/// comma or a point, at most two decimals.
int? parseRateBps(String raw) {
  final match = RegExp(r'^\s*(\d{1,3})(?:[.,](\d{0,2}))?\s*$').firstMatch(raw);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(match.group(1)!) * 100 + int.parse(fraction);
}

/// The inverse, for prefilling a rate field in the locale's own spelling.
String formatRateInput(int bps, String locale) {
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return '${bps ~/ 100}$separator${(bps % 100).toString().padLeft(2, '0')}';
}

/// A term in whole years when it is one — « 25 ans » — else in months.
String termLabel(AppLocalizations l10n, int months) => months % 12 == 0
    ? l10n.simulatorYears(months ~/ 12)
    : l10n.simulatorMonths(months);

/// A loan's term read in full: « 25 ans · 300 mois » on a whole number of
/// years, « 90 mois » otherwise, where a year count would be rounded.
String termValueLabel(AppLocalizations l10n, int months) => months % 12 == 0
    ? l10n.simulatorTermValue(months, months ~/ 12)
    : l10n.simulatorMonths(months);
