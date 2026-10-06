import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Locale-formatted, tabular-figure money text with the sign color rule
/// (income positive = green, expense negative = red).
/// Takes the canonical integer-minor-units + currency code and formats only
/// here, at the presentation edge — see the flutter-frontend skill.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amountMinor,
    required this.currency,
    this.style,
    this.showPositiveSign = false,
    this.colorize = true,
    this.maxLines,
  });

  final int amountMinor;
  final String currency;
  final TextStyle? style;

  /// Prefix positive amounts with `+`. Off for balances (a balance isn't a
  /// movement); on for transaction amounts, where the explicit sign is what
  /// keeps the income/expense distinction from resting on color alone.
  final bool showPositiveSign;

  /// Apply the semantic money colors. Turn off where the amount is a neutral
  /// figure — a total, a form value — rather than an inflow or outflow.
  final bool colorize;

  /// Caps the amount at this many lines, ellipsizing past it. Set to 1 in a
  /// column narrow enough to wrap: an amount broken across two lines stops
  /// reading as one figure, and « 2 850,00 » over « € » is worse than a clipped
  /// number the user can widen the window to see.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formatted = formatAmount(
      amountMinor: amountMinor,
      currency: currency,
      locale: locale,
      showPositiveSign: showPositiveSign,
    );
    final base = style ?? DefaultTextStyle.of(context).style;
    final color = !colorize
        ? base.color
        : switch (amountMinor) {
            > 0 => AppColors.positive,
            < 0 => AppColors.negative,
            _ => base.color,
          };

    return Text(
      formatted,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: tabularNumberStyle(base).copyWith(color: color),
    );
  }
}

/// The U+2212 minus sign. `intl` emits an ASCII hyphen-minus, which is narrower
/// than the digits around it and breaks the tabular alignment the spec relies on
/// for stacked amount columns.
const _minusSign = '−';

/// Formats integer minor units for display. Exposed separately from
/// [AmountText] for the places that need the string rather than the widget —
/// chart tooltips, semantics labels, legend rows.
String formatAmount({
  required int amountMinor,
  required String currency,
  required String locale,
  bool showPositiveSign = false,
}) {
  // `simpleCurrency` rather than `currency`: the latter prints the ISO code
  // where the glyph belongs ("EUR 2 850,00"), and every amount in the spec reads
  // with the symbol — `2 850,00 €`, `€2,850.00`. A code with no distinct glyph
  // still falls back to the code itself, which is what we want.
  final formatted = NumberFormat.simpleCurrency(
    locale: locale,
    name: currency,
  ).format(amountMinor / 100).replaceAll('-', _minusSign);

  if (showPositiveSign && amountMinor > 0) return '+$formatted';
  return formatted;
}
