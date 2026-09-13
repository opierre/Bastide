import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import 'debt_ratio_card.dart';
import 'mortgage_card.dart';
import 'mortgage_detail.dart';
import 'mortgage_form_modal.dart';
import 'mortgage_labels.dart';
import 'trajectory_chart.dart';

/// The Crédits panel (`docs/design/12-credits.md`): the summary row with the
/// debt ratio, the loan cards, the trajectory chart, and the loan detail.
///
/// No figure on it is computed in Dart — every amount, share and ratio is the
/// backend engine's (`PROJECT.md` §15).
class MortgagesScreen extends ConsumerWidget {
  const MortgagesScreen({super.key});

  static const path = '/mortgages';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMortgageProvider);

    return Padding(
      key: const Key('screen-mortgages'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: selected == null
          ? const _MortgagesList()
          : MortgageDetailPanel(mortgageId: selected),
    );
  }
}

/// The panel's contribution to the top bar: the primary « Nouveau crédit ».
/// It stays on the detail view — the detail is a state of this panel, and the
/// chrome does not rearrange itself under the user.
class MortgagesTopBarActions extends StatelessWidget {
  const MortgagesTopBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      key: const Key('addMortgageButton'),
      label: AppLocalizations.of(context)!.mortgagesAdd,
      icon: Icons.add_rounded,
      onPressed: () => showMortgageForm(context),
    );
  }
}

class _MortgagesList extends ConsumerWidget {
  const _MortgagesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(mortgagesControllerProvider);

    return switch (state) {
      AsyncData(:final value)
          when value.mortgages.isEmpty && value.statusFilter == null =>
        const _EmptyState(),
      AsyncData(:final value) => _LoadedPanel(state: value),
      AsyncError() => ErrorStateView(
        message: l10n.mortgagesLoadFailed,
        messageKey: const Key('mortgagesErrorText'),
        retryLabel: l10n.mortgagesRetry,
        retryKey: const Key('mortgagesRetryButton'),
        onRetry: () => ref.read(mortgagesControllerProvider.notifier).refresh(),
      ),
      _ => const _LoadingView(),
    };
  }
}

/// Frame ⑥: the summary row and the chart are not drawn — there is nothing to
/// sum and no trajectory to draw — only the offer to declare a first loan.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return CenteredStatePane(
      key: const Key('mortgagesEmptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.irisSoft,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const SizedBox.square(
              dimension: 27,
              child: FittedBox(
                child: NavGlyphIcon(
                  glyph: NavGlyph.house,
                  filled: false,
                  color: AppColors.iris,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.mortgagesEmptyTitle,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            l10n.mortgagesEmptyBody,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          PrimaryButton(
            key: const Key('mortgagesEmptyCta'),
            label: l10n.mortgagesAdd,
            icon: Icons.add_rounded,
            height: 44,
            onPressed: () => showMortgageForm(context),
          ),
        ],
      ),
    );
  }
}

/// The list's silhouettes: three summary cards, two loan cards, the chart.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('mortgagesLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 100,
                  child: SkeletonBlock(height: double.infinity),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 100,
                  child: SkeletonBlock(height: double.infinity),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 150,
                  child: SkeletonBlock(height: double.infinity),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.gridGap),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SkeletonBlock(height: double.infinity)),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.gridGap),
          Expanded(child: SkeletonBlock(height: double.infinity)),
        ],
      ),
    );
  }
}

class _LoadedPanel extends ConsumerWidget {
  const _LoadedPanel({required this.state});

  final MortgagesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(mortgagesTodayProvider)();
    const gap = SliverToBoxAdapter(child: SizedBox(height: AppSpacing.gridGap));

    return CustomScrollView(
      key: const Key('mortgagesList'),
      slivers: [
        if (state.actionError != null) ...[
          SliverToBoxAdapter(
            child: InlineBanner(
              key: const Key('mortgagesActionError'),
              message: localizeMortgageError(l10n, state.actionError),
              onDismiss: ref
                  .read(mortgagesControllerProvider.notifier)
                  .clearActionError,
              dismissTooltip: l10n.mortgageFormCancel,
            ),
          ),
          gap,
        ],
        SliverToBoxAdapter(child: _SummaryRow(summary: state.summary)),
        gap,
        SliverToBoxAdapter(child: _LoanGrid(mortgages: state.mortgages)),
        if (state.summary.outstandingSeries.length >= 2) ...[
          gap,
          // Fills what the cards leave of the frame, and keeps a readable
          // minimum when a third loan pushes the grid taller.
          SliverFillRemaining(
            hasScrollBody: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 280),
              child: TrajectoryChartCard(state: state, today: today),
            ),
          ),
        ],
      ],
    );
  }
}

/// Frame ①'s three summary cards, `1fr 1fr 1.5fr`, read straight from
/// `/mortgages/summary`.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 100, child: _ChargeCard(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 100, child: _OutstandingCard(summary: summary)),
          const SizedBox(width: AppSpacing.gridGap),
          Expanded(flex: 150, child: DebtRatioCard(summary: summary)),
        ],
      ),
    );
  }
}

/// The panel's one iris-tinted card: the monthly charge is the figure a
/// household plans around.
class _ChargeCard extends StatelessWidget {
  const _ChargeCard({required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final next = summary.nextPaymentOn;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      gradient: AppColors.irisTintGradient,
      border: Border.all(color: AppColors.irisBorderStrong),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.mortgagesChargeLabel.toUpperCase(),
            style: AppTextStyles.statLabel.copyWith(color: AppColors.iris),
          ),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            key: const Key('mortgagesMonthlyCharge'),
            amountMinor: summary.monthlyChargeMinor,
            currency: summary.currency,
            colorize: false,
            maxLines: 1,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            next == null
                ? l10n.mortgagesChargeCaptionNoNext
                : l10n.mortgagesChargeCaption(
                    summary.nextPaymentCount,
                    mortgageDateFormat(locale).format(next),
                  ),
            key: const Key('mortgagesChargeCaption'),
            style: AppTextStyles.helper.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (final charge in summary.byLender)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            MonogramAvatar.hueFor(charge.lender) ??
                            MonogramHues.unknownForeground,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Flexible(
                      child: Text(
                        charge.lender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.helper.copyWith(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      formatAmount(
                        amountMinor: charge.monthlyChargeMinor,
                        currency: summary.currency,
                        locale: locale,
                      ),
                      style: tabularNumberStyle(
                        AppTextStyles.helper,
                      ).copyWith(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: AppSpacing.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.mortgagesOutstandingLabel.toUpperCase(),
            style: AppTextStyles.statLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          AmountText(
            key: const Key('mortgagesTotalOutstanding'),
            amountMinor: summary.totalOutstandingMinor,
            currency: summary.currency,
            colorize: false,
            maxLines: 1,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            l10n.mortgagesOutstandingCaption(
              money(summary.totalPrincipalMinor),
              summary.activeCount,
            ),
            style: AppTextStyles.helper.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          LoanProgressBar(bps: summary.repaidBps),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            l10n.mortgagesRepaidLine(
              money(summary.repaidPrincipalMinor),
              formatBps(summary.repaidBps, locale),
            ),
            key: const Key('mortgagesRepaidLine'),
            style: tabularNumberStyle(
              AppTextStyles.helper,
            ).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The loan cards, two to a row, each row as tall as its taller card.
class _LoanGrid extends ConsumerWidget {
  const _LoanGrid({required this.mortgages});

  final List<Mortgage> mortgages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget card(Mortgage mortgage) => MortgageCard(
      mortgage: mortgage,
      onOpen: () =>
          ref.read(selectedMortgageProvider.notifier).open(mortgage.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < mortgages.length; index += 2) ...[
          if (index > 0) const SizedBox(height: AppSpacing.gridGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(mortgages[index])),
                const SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  child: index + 1 < mortgages.length
                      ? card(mortgages[index + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
