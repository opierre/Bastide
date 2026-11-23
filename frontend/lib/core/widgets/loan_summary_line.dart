import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/loan_display.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'amount_text.dart';
import 'summary_line.dart';

/// The figures a loan's summary line prints: the engine's answer for one set
/// of terms, with the three terms its captions name. Each feature maps its
/// own compute response onto it.
typedef LoanSummaryFigures = ({
  int totalInstalmentMinor,
  int monthlyPaymentMinor,
  int insuranceMonthlyMinor,
  int termMonths,
  int totalCostMinor,
  int totalInterestMinor,
  int totalInsuranceMinor,
  int upfrontFeesMinor,
  int taegBps,
});

/// A computed loan's summary line (`14-simulateur.md` §Reading pane, 1; the
/// loan form's reading pane in `12-credits.md`): « Échéance mensuelle » leads
/// at 40 px, then « Coût total » and « TAEG indicatif » at 20 px,
/// bottom-aligned and split by vertical hairlines.
///
/// Every figure is the API's and neutral. Before anything computes
/// ([figures] `null`) the figures are « — » `textTertiary` and the lead's
/// caption is [emptyCaption], which says what is missing.
class LoanSummaryLine extends StatelessWidget {
  const LoanSummaryLine({
    super.key,
    required this.figures,
    required this.currency,
    required this.emptyCaption,
    this.captionMaxLines = 2,
  });

  final LoanSummaryFigures? figures;
  final String currency;
  final String emptyCaption;

  /// Two lines on the Simulateur's wide reading pane; three in the loan
  /// form's narrower one, so no caption ends on an ellipsis.
  final int captionMaxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final figures = this.figures;

    String money(int minor) =>
        formatAmount(amountMinor: minor, currency: currency, locale: locale);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 5,
            child: _SummaryItem(
              id: 'Instalment',
              captionMaxLines: captionMaxLines,
              label: l10n.simulatorInstalmentLabel,
              labelGap: AppSpacing.xs,
              value: figures == null
                  ? null
                  : money(figures.totalInstalmentMinor),
              valueStyle: textTheme.displayLarge!,
              caption: figures == null
                  ? emptyCaption
                  : l10n.simulatorInstalmentCaption(
                      money(figures.monthlyPaymentMinor),
                      money(figures.insuranceMonthlyMinor),
                      figures.termMonths,
                    ),
            ),
          ),
          const SummaryHairline(),
          Flexible(
            flex: 4,
            child: _SummaryItem(
              id: 'Cost',
              captionMaxLines: captionMaxLines,
              label: l10n.simulatorCostLabel,
              value: figures == null ? null : money(figures.totalCostMinor),
              valueStyle: textTheme.displaySmall!,
              caption: figures == null
                  ? null
                  : l10n.simulatorCostCaption(
                      money(figures.totalInterestMinor),
                      money(figures.totalInsuranceMinor),
                      money(figures.upfrontFeesMinor),
                    ),
            ),
          ),
          const SummaryHairline(),
          Flexible(
            flex: 3,
            child: _SummaryItem(
              id: 'Taeg',
              captionMaxLines: captionMaxLines,
              // « indicatif » is part of the TAEG label itself.
              label: l10n.simulatorTaegLabel,
              value: figures == null
                  ? null
                  : formatRate(figures.taegBps, locale),
              valueStyle: textTheme.displaySmall!,
              caption: l10n.simulatorTaegCaption,
            ),
          ),
        ],
      ),
    );
  }
}

/// A [SummaryItem] whose figure is the API's string, or the dash before
/// anything computes.
class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.id,
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.caption,
    required this.captionMaxLines,
    this.labelGap = AppSpacing.xsPlus,
  });

  /// Suffix of the item's keys: `result<id>`, `result<id>Caption`.
  final String id;
  final String label;

  /// `null` draws the dash.
  final String? value;
  final TextStyle valueStyle;
  final String? caption;
  final int captionMaxLines;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return SummaryItem(
      key: Key('result${id}Item'),
      label: label,
      labelKey: Key('result${id}Label'),
      labelGap: labelGap,
      caption: caption,
      captionKey: Key('result${id}Caption'),
      captionMaxLines: captionMaxLines,
      figure: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value ?? l10n.simulatorNoValue,
          key: Key('result$id'),
          maxLines: 1,
          style: tabularNumberStyle(
            valueStyle,
          ).copyWith(color: value == null ? colors.textTertiary : colors.text),
        ),
      ),
    );
  }
}
