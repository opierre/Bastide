import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// Builds the `EUR — € — Euro` label the currency select-look shows.
///
/// The symbol comes from `intl` (locale-aware), the name from the ARB. `intl`
/// ships symbols but not currency display names, so the names are localized
/// keys like any other user-facing string.
String currencyLabel(AppLocalizations l10n, String code, String locale) {
  final symbol = NumberFormat.simpleCurrency(
    locale: locale,
    name: code,
  ).currencySymbol;
  final name = currencyName(l10n, code);

  // A few codes have no distinct symbol — intl echoes the code back. Showing
  // "XOF — XOF — Franc CFA" reads as a bug, so the symbol is dropped there.
  if (symbol == code) return '$code — $name';
  return '$code — $symbol — $name';
}

/// Localized display name for an ISO-4217 code in [supportedCurrencies].
///
/// A switch rather than a map because the generated localizations expose one
/// getter per key; an unknown code falls back to the code itself, which is
/// still meaningful.
String currencyName(AppLocalizations l10n, String code) => switch (code) {
  'EUR' => l10n.currencyNameEUR,
  'USD' => l10n.currencyNameUSD,
  'GBP' => l10n.currencyNameGBP,
  'CHF' => l10n.currencyNameCHF,
  'CAD' => l10n.currencyNameCAD,
  'JPY' => l10n.currencyNameJPY,
  'AUD' => l10n.currencyNameAUD,
  'CNY' => l10n.currencyNameCNY,
  'INR' => l10n.currencyNameINR,
  'BRL' => l10n.currencyNameBRL,
  'MXN' => l10n.currencyNameMXN,
  'SEK' => l10n.currencyNameSEK,
  'NOK' => l10n.currencyNameNOK,
  'DKK' => l10n.currencyNameDKK,
  'PLN' => l10n.currencyNamePLN,
  'CZK' => l10n.currencyNameCZK,
  'HUF' => l10n.currencyNameHUF,
  'RON' => l10n.currencyNameRON,
  'ZAR' => l10n.currencyNameZAR,
  'AED' => l10n.currencyNameAED,
  'SGD' => l10n.currencyNameSGD,
  'HKD' => l10n.currencyNameHKD,
  'NZD' => l10n.currencyNameNZD,
  'TRY' => l10n.currencyNameTRY,
  'ILS' => l10n.currencyNameILS,
  'KRW' => l10n.currencyNameKRW,
  'THB' => l10n.currencyNameTHB,
  'MAD' => l10n.currencyNameMAD,
  'XOF' => l10n.currencyNameXOF,
  'XAF' => l10n.currencyNameXAF,
  _ => code,
};
