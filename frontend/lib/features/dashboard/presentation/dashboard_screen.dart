import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';
import 'category_breakdown.dart';
import 'income_vs_expense.dart';
import 'recent_activity.dart';
import 'savings_trend.dart';
import 'stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const path = '/dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stateAsync = ref.watch(dashboardControllerProvider);

    return Padding(
      key: const Key('screen-dashboard'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: switch (stateAsync) {
        AsyncData(:final value) when value.summary.isEmpty => _EmptyState(
          onGoToImports: () => context.go(ImportsScreen.path),
        ),
        AsyncData(:final value) => _DashboardContent(state: value),
        AsyncError(:final error) => ErrorStateView(
          message: _localizeError(l10n, error),
          messageKey: const Key('dashboardErrorText'),
          retryLabel: l10n.dashboardRetry,
          retryKey: const Key('dashboardRetryButton'),
          onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
        ),
        _ => const _DashboardSkeleton(key: Key('dashboardLoadingIndicator')),
      },
    );
  }
}

String _localizeError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure && error.code == 'DASHBOARD_MONTH_INVALID') {
    return l10n.dashboardErrorInvalidMonth;
  }
  return l10n.dashboardErrorGeneric;
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final summary = state.summary;
    // The month the deltas compare against — « vs avril » when May is selected.
    final previousMonth = DateTime(state.month.year, state.month.month - 1);
    final goal = formatWholePct(savingsRateGoal * 100, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `1fr 1fr 1fr 1.35fr` from the spec's grid, expressed as integer flex —
              // Flutter's `flex` is a whole number, so the ratio is scaled by 100 rather
              // than rounded to 1:1:1:1 (too narrow) or 1:1:1:2 (too wide).
              Expanded(
                flex: 100,
                child: StatCard(
                  label: l10n.dashboardStatIncome,
                  amountMinor: summary.incomeMinor,
                  currency: summary.currency,
                  deltaPct: summary.incomeDeltaPct,
                  caption: l10n.dashboardStatVsPreviousMonth(previousMonth),
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                flex: 100,
                child: StatCard(
                  label: l10n.dashboardStatExpense,
                  amountMinor: -summary.expenseMinor,
                  currency: summary.currency,
                  deltaPct: summary.expenseDeltaPct,
                  caption: l10n.dashboardStatVsPreviousMonth(previousMonth),
                  // The one card where a rise is bad news: spending more than last month is
                  // red, spending less is green.
                  invertTrendColor: true,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                flex: 100,
                child: StatCard(
                  label: l10n.dashboardStatNet,
                  amountMinor: summary.netMinor,
                  currency: summary.currency,
                  deltaPct: summary.netDeltaPct,
                  caption: l10n.dashboardStatNetCaption,
                  colorizeAmount: false,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                flex: 135,
                child: SavingsRateCard(
                  label: l10n.dashboardStatSavingsRate,
                  rate: summary.savingsRate,
                  deltaPct: summary.savingsRateDeltaPct,
                  deltaLabel: l10n.dashboardSavingsDeltaPoints(
                    formatSignedMagnitude(summary.savingsRateDeltaPct, locale),
                  ),
                  caption: summary.savingsGoalReached
                      ? l10n.dashboardSavingsGoalReached(goal)
                      : l10n.dashboardSavingsGoalPending(goal),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gridGap),
        SizedBox(
          // Fixed 322px, per the spec's row 2 — the donut's geometry is pinned, so the row
          // can't be left to take whatever height happens to be over.
          height: _row2Height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 135,
                child: CategoryBreakdownChart(
                  categories: summary.byCategory,
                  currency: summary.currency,
                  month: state.month,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                flex: 100,
                child: SavingsTrendChart(trends: state.trends),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: IncomeVsExpenseChart(trends: state.trends)),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                child: RecentActivityCard(
                  transactions: state.recent,
                  onViewAll: () => context.go(TransactionsScreen.path),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Row 2's pinned height from `docs/design/04-dashboard.md`.
const _row2Height = 322.0;

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGoToImports});

  final VoidCallback onGoToImports;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.bar_chart_rounded,
      title: l10n.dashboardEmptyTitle,
      message: l10n.dashboardEmptyBody,
      // A *primary* CTA, per the EmptyState in `docs/design/00` §Components — this is the one
      // action the panel wants, not an alternative to something else on screen.
      action: PrimaryButton(
        key: const Key('dashboardGoToImportsButton'),
        onPressed: onGoToImports,
        label: l10n.dashboardGoToImports,
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // The silhouette mirrors the populated panel's three rows and their exact ratios, so the
    // cards don't jump sideways or resize when the data lands — which is the whole reason a
    // skeleton beats a centred spinner.
    return const SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(flex: 100, child: SkeletonBlock(height: 132)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 100, child: SkeletonBlock(height: 132)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 100, child: SkeletonBlock(height: 132)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 135, child: SkeletonBlock(height: 132)),
            ],
          ),
          SizedBox(height: AppSpacing.gridGap),
          SizedBox(
            height: _row2Height,
            child: Row(
              children: [
                Expanded(flex: 135, child: SkeletonBlock(height: double.infinity)),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(flex: 100, child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.gridGap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: SkeletonBlock(height: double.infinity)),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
