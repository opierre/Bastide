import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/loan_display.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_slider.dart';

/// « Durée » with its value on the same line, a slider over [minMonths] to
/// [maxMonths] in steps of [stepMonths], and the end labels 11 `textTertiary`
/// (`14-simulateur.md` §Inputs pane, 3; the loan form in `12-credits.md`).
///
/// The Simulateur steps a year at a time over 5–30 years; the loan form steps
/// a month at a time, since a contracted term need not be whole years. A
/// value outside the range (a loan saved longer than the scale) keeps its
/// figure; only the thumb rests at the end.
class TermSlider extends StatelessWidget {
  const TermSlider({
    super.key,
    required this.termMonths,
    required this.onChanged,
    required this.minMonths,
    required this.maxMonths,
    required this.stepMonths,
    this.sliderKey,
    this.valueKey,
  });

  final int termMonths;
  final ValueChanged<int>? onChanged;
  final int minMonths;
  final int maxMonths;
  final int stepMonths;
  final Key? sliderKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final bounds = textTheme.labelSmall!.copyWith(color: colors.textTertiary);
    final onChanged = this.onChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.simulatorTerm,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              termValueLabel(l10n, termMonths),
              key: valueKey,
              style: tabularNumberStyle(
                textTheme.bodySmall!,
              ).copyWith(color: colors.text),
            ),
          ],
        ),
        AppSlider(
          key: sliderKey,
          value: termMonths.toDouble(),
          min: minMonths.toDouble(),
          max: maxMonths.toDouble(),
          divisions: (maxMonths - minMonths) ~/ stepMonths,
          width: double.infinity,
          semanticFormatter: (months) => termValueLabel(l10n, months.round()),
          onChanged: onChanged == null
              ? null
              : (months) => onChanged(months.round()),
        ),
        Row(
          children: [
            Text(termLabel(l10n, minMonths), style: bounds),
            const Spacer(),
            Text(termLabel(l10n, maxMonths), style: bounds),
          ],
        ),
      ],
    );
  }
}
