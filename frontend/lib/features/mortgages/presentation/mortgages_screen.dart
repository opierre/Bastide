import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_line.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/mortgage.dart';
import 'debt_ratio_item.dart';
import 'loan_summary_item.dart';
import 'loans_table.dart';
import 'mortgage_detail.dart';
import 'mortgage_form_modal.dart';
import 'mortgage_labels.dart';
import 'trajectory_chart.dart';

/// The Crédits panel (`docs/design/12-credits.md`): the summary line with the
/// debt ratio, the loans table and the trajectory chart; or one loan's detail.
///
/// No figure on it is computed in Dart: every amount, share and ratio is the
/// backend engine's.
class MortgagesScreen extends ConsumerWidget {
  const MortgagesScreen({super.key});

  static const path = '/mortgages';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMortgageProvider);

    return Padding(
      key: const Key('screen-mortgages'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: selected == null
          ? const _MortgagesList()
          : MortgageDetailPanel(mortgageId: selected),
    );
  }
}

/// The panel's title: « Crédits », or, on an open loan, « Crédits / »
/// leading back to the list, then the loan's name.
class MortgagesTitle extends ConsumerWidget {
  const MortgagesTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedMortgageProvider);
    if (selected == null) return TitleBarTitle(title: l10n.navMortgages);

    final label = ref
        .watch(mortgageDetailProvider(selected))
        .value
        ?.detail
        .mortgage
        .label;
    return TitleBarTitle(
      key: const Key('mortgageDetailTitle'),
      crumb: TitleBarCrumb(
        label: l10n.navMortgages,
        onTap: () => ref.read(selectedMortgageProvider.notifier).close(),
      ),
      title: label ?? '',
    );
  }
}

/// The panel's contribution to the title bar: the primary « Nouveau crédit »
/// on the list, the secondary « Modifier » on an open loan.
class MortgagesTopBarActions extends ConsumerWidget {
  const MortgagesTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedMortgageProvider);
    if (selected != null) {
      final mortgage = ref
          .watch(mortgageDetailProvider(selected))
          .value
          ?.detail
          .mortgage;
      return AppButton(
        key: const Key('mortgageDetailEdit'),
        label: l10n.mortgageDetailEdit,
        onPressed: mortgage == null
            ? null
            : () => showMortgageForm(context, initial: mortgage),
      );
    }
    return PrimaryButton(
      key: const Key('addMortgageButton'),
      label: l10n.mortgagesAdd,
      icon: LucideIcons300.plus,
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
        // No summary and no chart: there is nothing to sum or to draw.
        EmptyStateView(
          key: const Key('mortgagesEmptyState'),
          title: l10n.mortgagesEmptyTitle,
          message: l10n.mortgagesEmptyBody,
          action: PrimaryButton(
            key: const Key('mortgagesEmptyCta'),
            label: l10n.mortgagesAdd,
            icon: LucideIcons300.plus,
            onPressed: () => showMortgageForm(context),
          ),
        ),
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

/// The list's own silhouette: the summary line, two table rows, the chart.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      key: Key('mortgagesLoading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBlock(height: AppSpacing.xxl * 2, width: 240),
              SizedBox(width: AppSpacing.xxl),
              SkeletonBlock(height: AppSpacing.xxl * 1.5, width: 200),
              SizedBox(width: AppSpacing.xxl),
              SkeletonBlock(
                height: AppSpacing.xxl * 2,
                width: AppLoans.ratioWidth,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.section),
          SkeletonBlock(height: AppSizes.tableRowTwoLines),
          SizedBox(height: AppSpacing.xs),
          SkeletonBlock(height: AppSizes.tableRowTwoLines),
          SizedBox(height: AppSpacing.section),
          Expanded(child: SkeletonBlock(height: double.infinity)),
        ],
      ),
    );
  }
}

class _LoadedPanel extends ConsumerWidget {
  const _LoadedPanel({required this.state});

  final MortgagesState state;

  /// Below this the chart stops shrinking and the panel scrolls instead.
  static const _chartMinHeight = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(mortgagesTodayProvider)();
    const gap = SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section));

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
        SliverToBoxAdapter(child: LoansSummaryLine(summary: state.summary)),
        gap,
        SliverToBoxAdapter(
          child: LoansTable(
            mortgages: state.mortgages,
            onOpen: (mortgage) =>
                ref.read(selectedMortgageProvider.notifier).open(mortgage.id),
          ),
        ),
        if (state.summary.outstandingSeries.length >= 2) ...[
          gap,
          // Takes the height the table leaves, and keeps a readable minimum
          // when more loans push the table taller.
          SliverFillRemaining(
            hasScrollBody: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _chartMinHeight),
              child: TrajectorySection(state: state, today: today),
            ),
          ),
        ],
      ],
    );
  }
}

/// The panel's summary line (`12-credits.md` §1): « Charge mensuelle » leads
/// at 40 px, then « Capital restant dû » at 20 px and the debt ratio, with a
/// vertical hairline between the three. Read straight from
/// `/mortgages/summary`.
///
/// The debt ratio carries a repère, a two-line caption and sometimes an
/// action under its figure, so bottom-aligning the items (`00` §7) would lift
/// its figure above the others. The items are laid out from the top instead,
/// with every figure on the lead's baseline: the three figures share one
/// baseline, and the captions and the repère start on one line under them.
class LoansSummaryLine extends StatelessWidget {
  const LoansSummaryLine({super.key, required this.summary});

  final MortgageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final next = summary.nextPaymentOn;

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: summary.currency,
      locale: locale,
    );

    return IntrinsicHeight(
      key: const Key('mortgagesSummaryLine'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: _TopAligned(
              child: LoanSummaryItem(
                lead: true,
                label: l10n.mortgagesChargeLabel,
                figure: money(summary.monthlyChargeMinor),
                figureKey: const Key('mortgagesMonthlyCharge'),
                caption: next == null
                    ? l10n.mortgagesChargeCaptionNoNext
                    : l10n.mortgagesChargeCaption(
                        summary.nextPaymentCount,
                        mortgageLongDateFormat(locale).format(next),
                      ),
                captionKey: const Key('mortgagesChargeCaption'),
              ),
            ),
          ),
          const SummaryHairline(),
          Flexible(
            child: _TopAligned(
              child: LoanSummaryItem(
                onLeadBaseline: true,
                label: l10n.mortgagesOutstandingLabel,
                figure: money(summary.totalOutstandingMinor),
                figureKey: const Key('mortgagesTotalOutstanding'),
                caption: l10n.mortgagesOutstandingCaption(
                  money(summary.totalPrincipalMinor),
                  formatBps(summary.repaidBps, locale),
                ),
                captionKey: const Key('mortgagesOutstandingCaption'),
              ),
            ),
          ),
          const SummaryHairline(),
          DebtRatioItem(summary: summary),
        ],
      ),
    );
  }
}

/// Holds a summary item at the top of the stretched line, at its own size:
/// the column hands it an unbounded height, so the item no longer fills the
/// line and falls to its bottom.
class _TopAligned extends StatelessWidget {
  const _TopAligned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [child]);
}
