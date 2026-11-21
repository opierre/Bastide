import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import '../domain/schedule_row.dart';
import 'loan_summary_item.dart';
import 'mortgage_labels.dart';
import 'schedule_table.dart';

/// One loan in full (`12-credits.md` § Loan detail): the summary line, the
/// cost line, then the amortisation table. The crumb, the loan's name and
/// « Modifier » live in the title bar.
///
/// No amortisation curve here: the table carries the numbers and the list's
/// trajectory chart the shape.
class MortgageDetailPanel extends ConsumerWidget {
  const MortgageDetailPanel({super.key, required this.mortgageId});

  final String mortgageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(mortgageDetailProvider(mortgageId));

    return KeyedSubtree(
      key: const Key('mortgageDetail'),
      child: switch (detail) {
        AsyncData(:final value) => MortgageDetailBody(view: value),
        AsyncError() => ErrorStateView(
          message: l10n.mortgageDetailLoadFailed,
          messageKey: const Key('mortgageDetailErrorText'),
          retryLabel: l10n.mortgagesRetry,
          retryKey: const Key('mortgageDetailRetryButton'),
          onRetry: () => ref.invalidate(mortgageDetailProvider(mortgageId)),
        ),
        _ => const _DetailLoading(),
      },
    );
  }
}

/// The detail's silhouette: two summary lines and the table.
class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('mortgageDetailLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: AppSpacing.xxl * 2),
          SizedBox(height: AppSpacing.section),
          SkeletonBlock(height: AppSpacing.xxl * 1.5),
          SizedBox(height: AppSpacing.section),
          Expanded(child: SkeletonBlock(height: double.infinity)),
        ],
      ),
    );
  }
}

class MortgageDetailBody extends ConsumerWidget {
  const MortgageDetailBody({super.key, required this.view});

  final MortgageDetailView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(mortgagesTodayProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailSummaryLine(detail: view.detail),
        const SizedBox(height: AppSpacing.section),
        _CostLine(view: view),
        const SizedBox(height: AppSpacing.section),
        Expanded(
          child: ScheduleSection(years: ScheduleYears.of(view.detail, today)),
        ),
      ],
    );
  }
}

/// « Échéance totale » leads at 40 px, then « Capital restant dû » and
/// « Prochaine échéance » at 20 px; on the right, two 12 `textSecondary`
/// lines naming the loan's terms.
class _DetailSummaryLine extends StatelessWidget {
  const _DetailSummaryLine({required this.detail});

  final MortgageDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final secondary = tabularNumberStyle(
      Theme.of(context).textTheme.bodySmall!,
    ).copyWith(color: context.colors.textSecondary);
    final mortgage = detail.mortgage;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: mortgage.currency,
      locale: locale,
    );

    final firstPayment = mortgageDateFormat(
      locale,
    ).format(mortgage.firstPaymentDate);

    return IntrinsicHeight(
      key: const Key('mortgageDetailSummaryLine'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: LoanSummaryItem(
              lead: true,
              label: l10n.mortgageDetailInstalmentLabel,
              figure: money(mortgage.totalInstalmentMinor),
              figureKey: const Key('mortgageDetailInstalment'),
              caption: mortgage.insuranceMonthlyMinor > 0
                  ? l10n.mortgageDetailInstalmentCaption(
                      money(mortgage.monthlyPaymentMinor),
                      money(mortgage.insuranceMonthlyMinor),
                    )
                  : l10n.mortgageDetailInstalmentNoInsurance,
              captionKey: const Key('mortgageDetailInstalmentCaption'),
            ),
          ),
          const LoanSummaryHairline(),
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgagesOutstandingLabel,
              figure: money(mortgage.outstandingPrincipalMinor),
              figureKey: const Key('mortgageDetailOutstanding'),
              caption: l10n.mortgageDetailOutstandingCaption(
                formatBps(mortgage.paidPrincipalBps, locale),
                mortgage.remainingMonths,
              ),
            ),
          ),
          const LoanSummaryHairline(),
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgageNextLabel,
              figure: switch (mortgage.nextPaymentOn) {
                final next? => mortgageLongDateFormat(locale).format(next),
                null => '—',
              },
              figureKey: const Key('mortgageDetailNext'),
              // The spec names the paying account here; a declared loan is
              // not linked to an account, so the lender stands in for it.
              caption: mortgage.lender,
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.mortgageDetailFacts(
                    mortgageKindLabel(l10n, mortgage.kind),
                    mortgage.lender,
                    money(mortgage.principalMinor),
                    mortgage.termMonths,
                  ),
                  key: const Key('mortgageDetailFacts'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: secondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mortgage.upfrontFeesMinor > 0
                      ? l10n.mortgageDetailFirstPaymentFees(
                          firstPayment,
                          money(mortgage.upfrontFeesMinor),
                        )
                      : l10n.mortgageDetailFirstPayment(firstPayment),
                  key: const Key('mortgageDetailFirstPayment'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cost line, a second summary line at 20 px: nominal rate, indicative
/// TAEG, total interest and total cost. « TAEG indicatif » says so in its
/// label: a real TAEG includes fees the app never sees.
class _CostLine extends StatelessWidget {
  const _CostLine({required this.view});

  final MortgageDetailView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final detail = view.detail;
    final mortgage = detail.mortgage;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: mortgage.currency,
      locale: locale,
    );

    return IntrinsicHeight(
      key: const Key('mortgageCostLine'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgageRateLabel,
              figure: formatBps(mortgage.annualRateBps, locale, digits: 2),
              figureKey: const Key('mortgageCostRate'),
              caption: l10n.mortgageCostRateCaption,
            ),
          ),
          const LoanSummaryHairline(),
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgageCostTaegLabel,
              figure: formatBps(detail.taegBps, locale, digits: 2),
              figureKey: const Key('mortgageCostTaeg'),
              caption: l10n.mortgageCostTaegCaption,
            ),
          ),
          const LoanSummaryHairline(),
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgageCostInterestLabel,
              figure: money(detail.totalInterestMinor),
              figureKey: const Key('mortgageCostInterest'),
              caption: l10n.mortgageCostInterestCaption(
                money(view.interestStillDueMinor),
              ),
            ),
          ),
          const LoanSummaryHairline(),
          Flexible(
            child: LoanSummaryItem(
              label: l10n.mortgageCostTotalLabel,
              figure: money(detail.totalCostMinor),
              figureKey: const Key('mortgageCostTotal'),
              caption: l10n.mortgageCostTotalCaption(
                money(detail.totalInsuranceMinor),
                money(mortgage.upfrontFeesMinor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
