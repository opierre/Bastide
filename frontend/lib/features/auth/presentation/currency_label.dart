import 'package:intl/intl.dart';

/// Builds the `€ — EUR` label every currency display shows.
///
/// The symbol leads because it is what the user recognises at a glance; the
/// ISO code follows as the unambiguous gloss behind it — several currencies
/// share the `$` and `£` glyphs, so the symbol alone would not identify one.
/// The symbol comes from `intl`, which resolves it per locale.
String currencyLabel(String code, String locale) {
  final symbol = NumberFormat.simpleCurrency(
    locale: locale,
    name: code,
  ).currencySymbol;

  // A few codes have no distinct symbol — intl echoes the code back. Showing
  // "XOF — XOF" reads as a bug, so the code stands on its own there.
  if (symbol == code) return code;
  return '$symbol — $code';
}
