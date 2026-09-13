import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import '../domain/schedule_row.dart';
import 'mortgage_form_modal.dart';
import 'mortgage_labels.dart';
import 'schedule_table.dart';

/// One loan in full (`12-credits.md` frame ②): the header, the cost row with the
/// indicative TAEG, and the amortisation table.
///
/// No amortisation curve here — the frames reject it: the table carries the
/// numbers and the list's trajectory chart already carries the shape.
class MortgageDetailPanel extends ConsumerWidget {
  const MortgageDetailPanel({super.key, required this.mortgageId});

  final String mortgageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(mortgageDetailProvider(mortgageId));

    return Column(
      key: const Key('mortgageDetail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A link, not a 38 px button: the frame budgets the whole detail —
        // header, cost row, twelve dense rows and the foot — into 900 px.
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            key: const Key('mortgageDetailBack'),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: () => ref.read(selectedMortgageProvider.notifier).close(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AppColors.iris,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    l10n.mortgageDetailBack,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.iris),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: switch (detail) {
            AsyncData(:final value) => MortgageDetailBody(view: value),
            AsyncError() => ErrorStateView(
              message: l10n.mortgageDetailLoadFailed,
              messageKey: const Key('mortgageDetailErrorText'),
              retryLabel: l10n.mortgagesRetry,
              retryKey: const Key('mortgageDetailRetryButton'),
              onRetry: () => ref.invalidate(mortgageDetailProvider(mortgageId)),
            ),
            _ => const SkeletonList(
              key: Key('mortgageDetailLoading'),
              itemCount: 3,
              itemHeight: 92,
            ),
          },
        ),
      ],
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
        _HeaderCard(detail: view.detail),
        const SizedBox(height: AppSpacing.gridGap),
        _CostRow(view: view),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(
          child: ScheduleTableCard(years: ScheduleYears.of(view.detail, today)),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final MortgageDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final mortgage = detail.mortgage;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: mortgage.currency,
      locale: locale,
    );

    final kind = mortgageKindLabel(l10n, mortgage.kind);
    final firstPayment = mortgageDateFormat(
      locale,
    ).format(mortgage.firstPaymentDate);
    final subline = mortgage.upfrontFeesMinor > 0
        ? l10n.mortgageDetailSublineFees(
            kind,
            mortgage.lender,
            money(mortgage.principalMinor),
            mortgage.termMonths,
            firstPayment,
            money(mortgage.upfrontFeesMinor),
          )
        : l10n.mortgageDetailSubline(
            kind,
            mortgage.lender,
            money(mortgage.principalMinor),
            mortgage.termMonths,
            firstPayment,
          );

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 26,
        vertical: AppSpacing.cardPadding,
      ),
      child: Row(
        children: [
          InstitutionAvatar(name: mortgage.lender, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mortgage.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subline,
                  key: const Key('mortgageDetailSubline'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Flexible rather than natural width: French captions run long, and
          // a header that ellipsizes a caption beats one that overflows.
          Flexible(
            flex: 2,
            child: _HeaderStat(
              label: l10n.mortgageDetailInstalmentLabel,
              value: money(mortgage.totalInstalmentMinor),
              valueKey: const Key('mortgageDetailInstalment'),
              caption: mortgage.insuranceMonthlyMinor > 0
                  ? l10n.mortgageDetailInstalmentCaption(
                      money(mortgage.monthlyPaymentMinor),
                      money(mortgage.insuranceMonthlyMinor),
                    )
                  : l10n.mortgageDetailInstalmentNoInsurance,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            flex: 2,
            child: _HeaderStat(
              label: l10n.mortgagesOutstandingLabel,
              value: money(mortgage.outstandingPrincipalMinor),
              valueKey: const Key('mortgageDetailOutstanding'),
              caption: l10n.mortgageDetailOutstandingCaption(
                formatBps(mortgage.paidPrincipalBps, locale),
                mortgage.remainingMonths,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            flex: 2,
            child: _HeaderStat(
              label: l10n.mortgageNextLabel,
              value: switch (mortgage.nextPaymentOn) {
                final next? => mortgageDateFormat(locale).format(next),
                null => '—',
              },
              valueKey: const Key('mortgageDetailNext'),
              // The lender, not an account: a declared loan is never linked to
              // the ledger (§15), so there is no account to name.
              caption: mortgage.lender,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          OutlinedButton(
            key: const Key('mortgageDetailEdit'),
            onPressed: () => showMortgageForm(context, initial: mortgage),
            child: Text(l10n.mortgageDetailEdit),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.caption,
  });

  final String label;
  final String value;
  final Key valueKey;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
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
            Theme.of(context).textTheme.titleSmall!,
          ).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.helper.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

/// Frame ②'s four cost cards. The TAEG carries its « INDICATIF » marker on the
/// label itself: a real TAEG includes fees the app never sees (§15).
class _CostRow extends StatelessWidget {
  const _CostRow({required this.view});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CostCard(
              label: Text(
                l10n.mortgageRateLabel.toUpperCase(),
                style: AppTextStyles.statLabel,
              ),
              value: formatBps(mortgage.annualRateBps, locale, digits: 2),
              valueKey: const Key('mortgageCostRate'),
              caption: l10n.mortgageCostRateCaption,
            ),
          ),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(
            child: _CostCard(
              label: Row(
                children: [
                  Text(
                    l10n.mortgageCostTaegLabel.toUpperCase(),
                    style: AppTextStyles.statLabel,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Semantics(
                    label: l10n.mortgageCostTaegDisclaimer,
                    child: Container(
                      key: const Key('mortgageTaegIndicative'),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x248B8CF9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          l10n.mortgageCostIndicative.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: AppFonts.geist,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.iris,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              value: formatBps(detail.taegBps, locale, digits: 2),
              valueKey: const Key('mortgageCostTaeg'),
              caption: l10n.mortgageCostTaegCaption,
            ),
          ),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(
            child: _CostCard(
              label: Text(
                l10n.mortgageCostInterestLabel.toUpperCase(),
                style: AppTextStyles.statLabel,
              ),
              value: money(detail.totalInterestMinor),
              valueKey: const Key('mortgageCostInterest'),
              caption: l10n.mortgageCostInterestCaption(
                money(view.interestStillDueMinor),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(
            child: _CostCard(
              label: Text(
                l10n.mortgageCostTotalLabel.toUpperCase(),
                style: AppTextStyles.statLabel,
              ),
              value: money(detail.totalCostMinor),
              valueKey: const Key('mortgageCostTotal'),
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

class _CostCard extends StatelessWidget {
  const _CostCard({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.caption,
  });

  final Widget label;
  final String value;
  final Key valueKey;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            style: tabularNumberStyle(
              Theme.of(context).textTheme.displayMedium!,
            ).copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Two lines at most: the detail budgets its cost row so the year's
          // table and foot still fit a 900 px frame below it.
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.helper,
          ),
        ],
      ),
    );
  }
}
