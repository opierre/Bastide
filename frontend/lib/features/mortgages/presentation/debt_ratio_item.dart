import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/mortgage.dart';
import 'mortgage_labels.dart';

/// « Taux d’endettement », the third item of the Crédits summary line
/// (`12-credits.md` §1): the label with the ratio on the same line, the
/// repère on its fixed 0–60 % scale with the HCSF 35 % mark, then the caption
/// naming the charge, the income and its source.
///
/// The ratio is a reading. Above the reference the tone is `warning`, never
/// `negative`; with no income no ratio is drawn. « Lecture indicative, qui
/// n’engage aucun prêteur. » is body text in every state, never a tooltip.
class DebtRatioItem extends StatelessWidget {
  const DebtRatioItem({super.key, required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final ratio = summary.debtRatioBps;
    final income = summary.monthlyIncomeMinor;
    final known =
        summary.incomeSource != IncomeSource.unknown &&
        ratio != null &&
        income != null;
    final over = known && summary.overLimit;
    final captionStyle = tabularNumberStyle(
      textTheme.bodySmall!,
    ).copyWith(color: colors.textTertiary);

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    final source = !known
        ? l10n.mortgagesRatioUnknown
        : summary.incomeSource == IncomeSource.declared
        ? l10n.mortgagesRatioCaptionDeclared(
            money(summary.monthlyChargeMinor),
            money(income),
          )
        : l10n.mortgagesRatioCaptionLedger(
            money(summary.monthlyChargeMinor),
            money(income),
          );

    // A declared income ends the ledger reading; Paramètres → Préférences
    // holds the one field that edits it (`09-settings.md` §Préférences).
    void declare() => context.go(SettingsScreen.path);

    return SizedBox(
      key: const Key('debtRatioItem'),
      width: AppLoans.ratioWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.mortgagesRatioLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.statLabel,
                      ),
                    ),
                    if (over) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: StatusText(
                          key: const Key('ratioOverLimit'),
                          label: l10n.mortgagesRatioOverLimit,
                          tone: StatusTone.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                known ? formatBps(ratio, locale) : '—',
                key: const Key('ratioValue'),
                style: tabularNumberStyle(
                  textTheme.displaySmall!,
                ).copyWith(color: known ? colors.text : colors.textTertiary),
              ),
            ],
          ),
          if (known) ...[
            const SizedBox(height: AppSpacing.xsPlus),
            // The tone follows the API's `over_limit` rather than a
            // comparison made here. The meter clamps its fill past 60 %; the
            // figure above stays exact.
            RepereMeter(
              key: const Key('ratioGauge'),
              fraction: ratio / AppLoans.ratioScaleBps,
              tone: summary.overLimit ? RepereTone.over : RepereTone.normal,
              markFraction: summary.hcsfLimitBps / AppLoans.ratioScaleBps,
              markLabel: l10n.mortgagesRatioReference(
                formatBps(summary.hcsfLimitBps, locale, digits: 0),
              ),
              semanticLabel: formatBps(ratio, locale),
            ),
          ],
          const SizedBox(height: AppSpacing.xsPlus),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: source),
                const TextSpan(text: ' '),
                TextSpan(text: l10n.mortgagesRatioCaveat),
              ],
            ),
            key: const Key('ratioCaption'),
            style: captionStyle,
          ),
          if (known && summary.incomeSource == IncomeSource.ledger) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _Link(
                key: const Key('ratioDeclareIncomeLink'),
                label: l10n.mortgagesRatioDeclareLink,
                onTap: declare,
              ),
            ),
          ],
          if (!known) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                key: const Key('ratioDeclareIncomeButton'),
                label: l10n.mortgagesRatioDeclareLink,
                onPressed: declare,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The link of `00` §6: `accent`, 12 px, underlined on hover.
class _Link extends StatefulWidget {
  const _Link({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.accent,
              decoration: _hovered ? TextDecoration.underline : null,
              decorationColor: colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
