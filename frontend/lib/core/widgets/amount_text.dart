import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Locale-formatted, tabular-figure money text with the sign color rule
/// (income positive = green, expense negative = red — see `PROJECT.md` §9).
/// Takes the canonical integer-minor-units + currency code and formats only
/// here, at the presentation edge — see the flutter-frontend skill.
class AmountText extends StatelessWidget {
  const AmountText({super.key, required this.amountMinor, required this.currency, this.style});

  final int amountMinor;
  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formatted = NumberFormat.currency(locale: locale, name: currency).format(amountMinor / 100);
    final base = style ?? DefaultTextStyle.of(context).style;
    final color = switch (amountMinor) {
      > 0 => AppColors.positive,
      < 0 => AppColors.negative,
      _ => base.color,
    };

    return Text(formatted, style: tabularNumberStyle(base).copyWith(color: color));
  }
}
