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
import '../../recurring/application/subscriptions_controller.dart';
import '../../recurring/presentation/subscriptions_screen.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../application/dashboard_band.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';
import '../domain/upcoming_charges.dart';
import 'category_habits.dart';
import 'category_spending.dart';
import 'goals_section.dart';
import 'monthly_savings.dart';
import 'reading_line.dart';
import 'upcoming_charges_section.dart';

/// « Tableau de bord », the « Lecture du mois » (`docs/design/04-dashboard.md`):
/// five blocks 24 px apart in the content region. The reading line, a
/// hairline, « Dépenses par catégorie » beside « Épargne mensuelle », a
/// hairline, then the bottom band: « Par rapport à vos habitudes » on the
/// left half, « Objectifs » beside « À venir » on the right half.
/// Sections, not cards: nothing here is framed.
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
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: switch (stateAsync) {
        AsyncData(:final value) when !value.hasTransactions => _EmptyState(
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

/// The height of the two chart sections: a heading, then up to eight 30 px
/// category rows, which the savings chart beside them matches.
const _chartsBlockHeight =
    _headingBand +
    DashboardSummary.maxSpendingRows * CategorySpending.rowHeight;

/// A section heading with its gap to the content (the segmented control on
/// « Épargne mensuelle » sets its height).
const _headingBand = AppSpacing.xxl;

/// The height of « Objectifs » and « À venir » at their fullest: a heading
/// band and four 48 px rows.
const _sideBlockHeight =
    _headingBand + UpcomingCharges.maxRows * AppSizes.tableRowTwoLines;

/// Below this height the bottom band no longer fits with a useful number of
/// rows, so the panel scrolls instead of squeezing it.
const _minFillHeight = 640.0;

/// The bottom band's height when the panel scrolls: room for the side blocks
/// at their fullest, which also gives the habits table six rows.
const _scrolledBottomHeight = _sideBlockHeight + AppSpacing.lg;

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = ref.watch(dashboardBandProvider);
    final summary = state.summary;

    void openCategory(String? categoryId, DateTime month) {
      focusTransactionsOnCategory(
        ref.read(transactionFiltersProvider.notifier),
        categoryId: categoryId,
        month: month,
      );
      context.go(TransactionsScreen.path);
    }

    final charts = SizedBox(
      height: _chartsBlockHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CategorySpending(
              summary: summary,
              onCategoryTap: (categoryId) =>
                  openCategory(categoryId, state.month),
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(child: MonthlySavings(trends: state.trends)),
        ],
      ),
    );

    Widget goals({required bool compact}) => GoalsSection(
      goals: band.goals,
      compact: compact,
      onViewAll: () => context.go(GoalsScreen.path),
      onOpen: (goalId) {
        ref.read(selectedGoalProvider.notifier).select(goalId);
        context.go(GoalsScreen.path);
      },
    );

    Widget upcoming(UpcomingCharges upcoming) => UpcomingChargesSection(
      upcoming: upcoming,
      onViewAll: () => context.go(SubscriptionsScreen.path),
      onOpen: (seriesId) {
        ref.read(selectedSeriesProvider.notifier).open(seriesId);
        context.go(SubscriptionsScreen.path);
      },
    );

    final habits = DashboardHabitsBlock(onCategoryTap: openCategory);
    // The right half of the band, laid out by what it has to show (`04`
    // « États »); `null` when both side blocks are hidden.
    final Widget? right = switch (band.layout) {
      DashboardBandLayout.goalsAndUpcoming => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: goals(compact: true)),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(child: upcoming(band.upcoming!)),
        ],
      ),
      DashboardBandLayout.goalsOnly => goals(compact: false),
      DashboardBandLayout.upcomingOnly => upcoming(band.upcoming!),
      DashboardBandLayout.habitsOnly => null,
    };

    final bottom = right == null
        ? habits
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: habits),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Align(
                  key: const Key('dashboardBandRight'),
                  alignment: AlignmentDirectional.topStart,
                  child: right,
                ),
              ),
            ],
          );

    List<Widget> top() => [
      ReadingLine(summary: summary, month: state.month),
      const SizedBox(height: AppSpacing.section),
      const _Hairline(),
      const SizedBox(height: AppSpacing.section),
      charts,
      const SizedBox(height: AppSpacing.section),
      const _Hairline(),
      const SizedBox(height: AppSpacing.section),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _minFillHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...top(),
              Expanded(child: bottom),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...top(),
              SizedBox(height: _scrolledBottomHeight, child: bottom),
            ],
          ),
        );
      },
    );
  }
}

/// The 1 px `line` between two blocks of the panel.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, child: ColoredBox(color: context.colors.line));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGoToImports});

  final VoidCallback onGoToImports;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      title: l10n.dashboardEmptyTitle,
      message: l10n.dashboardEmptyBody,
      action: PrimaryButton(
        key: const Key('dashboardGoToImportsButton'),
        onPressed: onGoToImports,
        label: l10n.dashboardGoToImports,
      ),
    );
  }
}

/// The reading line's silhouette height: label, 40 px figure, the repère
/// with its mark, the status line.
const _readingLineSilhouette = 132.0;

/// The silhouette of the five blocks, in `hover` blocks pulsing together, so
/// nothing moves when the data lands (`00` §7). The bottom band is drawn in
/// its full shape: the habits block on the left half, « Objectifs » and
/// « À venir » side by side on the right half, at their fullest height.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBlock(height: _readingLineSilhouette),
          SizedBox(height: AppSpacing.section),
          _Hairline(),
          SizedBox(height: AppSpacing.section),
          SizedBox(
            height: _chartsBlockHeight,
            child: Row(
              children: [
                Expanded(child: SkeletonBlock(height: double.infinity)),
                SizedBox(width: AppSpacing.gutter),
                Expanded(child: SkeletonBlock(height: double.infinity)),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.section),
          _Hairline(),
          SizedBox(height: AppSpacing.section),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SkeletonBlock(
                    key: Key('dashboardSkeletonHabits'),
                    height: double.infinity,
                  ),
                ),
                SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: SizedBox(
                    height: _sideBlockHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: SkeletonBlock(
                            key: Key('dashboardSkeletonGoals'),
                            height: double.infinity,
                          ),
                        ),
                        SizedBox(width: AppSpacing.gutter),
                        Expanded(
                          child: SkeletonBlock(
                            key: Key('dashboardSkeletonUpcoming'),
                            height: double.infinity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
