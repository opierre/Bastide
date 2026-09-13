import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mortgage.dart';
import 'mortgage_labels.dart';

/// One loan in the 2-column grid (`12-credits.md` §2).
///
/// A card rather than a table row: at five loans or fewer a header organises
/// less than it costs, and two loans of very different size each keep their
/// progress bar and dates at equal rank.
///
/// Every figure is neutral — an instalment is a scheduled charge, not a booked
/// transaction, so the ledger's red would state something false about it.
class MortgageCard extends StatelessWidget {
  const MortgageCard({super.key, required this.mortgage, required this.onOpen});

  final Mortgage mortgage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final id = mortgage.id;

    return AppCard(
      key: Key('mortgageCard-$id'),
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InstitutionAvatar(name: mortgage.lender),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mortgage.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.mortgageCardSubline(
                        mortgageKindLabel(l10n, mortgage.kind),
                        mortgage.lender,
                        mortgage.termMonths,
                      ),
                      key: Key('mortgageCardSubline-$id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    key: Key('mortgageCardInstalment-$id'),
                    amountMinor: mortgage.totalInstalmentMinor,
                    currency: mortgage.currency,
                    colorize: false,
                    style: textTheme.displayMedium!.copyWith(fontSize: 22),
                  ),
                  Text(
                    l10n.mortgageCardPerMonth,
                    style: AppTextStyles.helper.copyWith(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  l10n.mortgageCardOutstandingLabel,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              AmountText(
                key: Key('mortgageCardOutstanding-$id'),
                amountMinor: mortgage.outstandingPrincipalMinor,
                currency: mortgage.currency,
                colorize: false,
                style: textTheme.titleSmall!.copyWith(fontSize: 14),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                l10n.mortgageCardOutstandingOf(
                  formatAmount(
                    amountMinor: mortgage.principalMinor,
                    currency: mortgage.currency,
                    locale: locale,
                  ),
                ),
                style: tabularNumberStyle(
                  AppTextStyles.helper,
                ).copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LoanProgressBar(bps: mortgage.paidPrincipalBps),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                formatBps(mortgage.paidPrincipalBps, locale),
                key: Key('mortgageCardRepaid-$id'),
                style: tabularNumberStyle(
                  textTheme.bodySmall!,
                ).copyWith(color: AppColors.iris, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.mortgageCardRepaid,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                l10n.mortgageCardRemaining(mortgage.remainingMonths),
                key: Key('mortgageCardRemaining-$id'),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _FooterStat(
                  label: l10n.mortgageRateLabel,
                  value: formatBps(mortgage.annualRateBps, locale, digits: 2),
                  valueKey: Key('mortgageCardRate-$id'),
                ),
              ),
              Expanded(
                child: _FooterStat(
                  label: l10n.mortgageInsuranceLabel,
                  value: mortgage.insuranceMonthlyMinor == 0
                      ? '—'
                      : l10n.mortgageInsurancePerMonth(
                          formatAmount(
                            amountMinor: mortgage.insuranceMonthlyMinor,
                            currency: mortgage.currency,
                            locale: locale,
                          ),
                        ),
                  valueKey: Key('mortgageCardInsurance-$id'),
                ),
              ),
              Expanded(
                child: _FooterStat(
                  label: l10n.mortgageNextLabel,
                  value: switch (mortgage.nextPaymentOn) {
                    final next? => mortgageDateFormat(locale).format(next),
                    null => '—',
                  },
                  valueKey: Key('mortgageCardNext-$id'),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.sectionLabel.copyWith(
            fontSize: 10.5,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tabularNumberStyle(
            Theme.of(context).textTheme.bodyMedium!,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// The 8 px repaid-share bar: an inset track with the iris gradient fill.
///
/// Takes the API's basis points as they are; the fraction is only the bar's
/// width, clamped so a rounding edge can never draw past the track.
class LoanProgressBar extends StatelessWidget {
  const LoanProgressBar({super.key, required this.bps});

  final int bps;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Container(
        height: 8,
        color: AppColors.surfaceHover,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (bps / 10000).clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.goalProgressGradient),
          ),
        ),
      ),
    );
  }
}
