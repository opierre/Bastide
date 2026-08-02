import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../application/dashboard_controller.dart';
import 'category_breakdown.dart';
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
    final summary = state.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: l10n.dashboardStatIncome,
                  amountMinor: summary.incomeMinor,
                  currency: summary.currency,
                  deltaPct: summary.incomeDeltaPct,
                  direction: TrendDirection.upIsGood,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                child: StatCard(
                  label: l10n.dashboardStatExpense,
                  amountMinor: -summary.expenseMinor,
                  currency: summary.currency,
                  deltaPct: summary.expenseDeltaPct,
                  direction: TrendDirection.upIsBad,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                child: StatCard(
                  label: l10n.dashboardStatNet,
                  amountMinor: summary.netMinor,
                  currency: summary.currency,
                  deltaPct: summary.netDeltaPct,
                  direction: TrendDirection.upIsGood,
                  colorizeAmount: false,
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                flex: 2,
                child: SavingsRateCard(
                  label: l10n.dashboardStatSavingsRate,
                  rate: summary.savingsRate,
                  deltaPct: summary.savingsRateDeltaPct,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(
          child: CategoryBreakdownChart(
            categories: summary.byCategory,
            currency: summary.currency,
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
      action: OutlinedButton(
        key: const Key('dashboardGoToImportsButton'),
        onPressed: onGoToImports,
        child: Text(l10n.dashboardGoToImports),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonBlock(height: 132)),
              const SizedBox(width: AppSpacing.gridGap),
              const Expanded(child: SkeletonBlock(height: 132)),
              const SizedBox(width: AppSpacing.gridGap),
              const Expanded(child: SkeletonBlock(height: 132)),
              const SizedBox(width: AppSpacing.gridGap),
              const Expanded(flex: 2, child: SkeletonBlock(height: 132)),
            ],
          ),
          const SizedBox(height: AppSpacing.gridGap),
          const Expanded(child: SkeletonBlock(height: double.infinity)),
        ],
      ),
    );
  }
}
