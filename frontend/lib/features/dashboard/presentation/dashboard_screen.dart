import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../goals/application/goals_controller.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';
import 'category_breakdown.dart';
import 'goals_progress_card.dart';
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
          onRetry: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
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

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // The top three active goals, or nothing at all — a goals load that hasn't
    // landed or has failed simply leaves row 3 with its two cards, rather
    // than putting an error about a side card on the dashboard.
    final goals =
        ref.watch(goalsControllerProvider).value?.topGoals ?? const [];
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
                  // The only colorized headline of the row: a positive net is green, a
                  // negative one red.
                  colorizeAmount: true,
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
        // Rows 2 and 3 split whatever is left below the stat grid, equally. The spec pins
        // row 2 at 322 px against its 1440×900 frame, but two 322 px rows overrun the content
        // region there — so the *relationship* is what's held: the two chart rows are always
        // the same height as each other, and together they fill the panel without scrolling.
        Expanded(
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
        // Row 3's three-card split, `1fr .95fr .85fr`, expressed as integer flex the
        // same way row 1's is. The Objectifs card is *dropped* rather than
        // collapsed when there are no goals, and the other two cards go back to
        // sharing the row equally — a third column held open for something the
        // user hasn't created reads as a rendering fault.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // The `1fr` the other two are measured against. Stated even
                // though it is the widest share: `Expanded` defaults to flex 1,
                // which against a sibling's 95 is not a wide column but an
                // invisible one.
                flex: 100,
                child: IncomeVsExpenseChart(trends: state.trends),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                // `.95fr` beside the left card's `1fr`, and back to an even
                // share when the Objectifs card is absent.
                flex: goals.isEmpty ? 100 : 95,
                child: RecentActivityCard(
                  transactions: state.recent,
                  onViewAll: () => context.go(TransactionsScreen.path),
                ),
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 85,
                  child: GoalsProgressCard(
                    goals: goals,
                    onViewAll: () => context.go(GoalsScreen.path),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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

/// The stat grid's measured height, so the skeleton's row 1 doesn't resize when data lands.
const _statRowHeight = 175.0;

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
              Expanded(flex: 100, child: SkeletonBlock(height: _statRowHeight)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 100, child: SkeletonBlock(height: _statRowHeight)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 100, child: SkeletonBlock(height: _statRowHeight)),
              SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 135, child: SkeletonBlock(height: _statRowHeight)),
            ],
          ),
          SizedBox(height: AppSpacing.gridGap),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 135,
                  child: SkeletonBlock(height: double.infinity),
                ),
                SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  flex: 100,
                  child: SkeletonBlock(height: double.infinity),
                ),
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
