import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';

/// The selected month alongside the summary loaded for it, plus the savings series.
///
/// The month is always the first of that month. [trends] is *not* keyed to it: its window
/// ends at the current calendar month, so paging the picker back leaves the savings
/// chart where it is.
@immutable
class DashboardState {
  const DashboardState({
    required this.month,
    required this.summary,
    required this.trends,
    required this.recent,
  });

  final DateTime month;
  final DashboardSummary summary;
  final DashboardTrends trends;

  /// Whether the user has any transaction at all. Without one the panel shows
  /// its empty state; a month without data still draws the panel with « — ».
  bool get hasTransactions => recent.isNotEmpty;

  /// The newest transactions, for « Activité récente ». Like [trends], not keyed to [month] —
  /// "recent" means recent, not "recent within the month you happen to be looking at".
  final List<RecentTransaction> recent;
}

/// Loads the dashboard summary for a selected month, defaulting to the latest month with data.
/// Month changes and the initial load both flow through this one controller — see
/// `TransactionsController` for the split-provider alternative, which isn't needed here since
/// there's only one axis of state (the month) rather than a whole filter set.
class DashboardController extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final repository = ref.read(dashboardRepositoryProvider);
    final month = await repository.latestMonthWithData() ?? _currentMonth();
    // Independent of each other, so they go out together rather than in series.
    final (summary, trends, recent) = await (
      repository.summary(month),
      repository.trends(),
      repository.recentTransactions(),
    ).wait;
    return DashboardState(
      month: month,
      summary: summary,
      trends: trends,
      recent: recent,
    );
  }

  Future<void> changeMonth(DateTime month) => _load(month);

  Future<void> refresh() {
    final current = state.value;
    return _load(current?.month ?? _currentMonth(), reloadTrends: true);
  }

  /// Reloads the summary for [month]. The trends and the activity list are re-fetched only on
  /// an explicit refresh: neither depends on the month, so paging the picker would otherwise
  /// re-request data that cannot have changed.
  Future<void> _load(DateTime month, {bool reloadTrends = false}) async {
    final previous = state.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(dashboardRepositoryProvider);
      final summary = await repository.summary(month);
      if (reloadTrends || previous == null) {
        final (trends, recent) = await (
          repository.trends(),
          repository.recentTransactions(),
        ).wait;
        return DashboardState(
          month: month,
          summary: summary,
          trends: trends,
          recent: recent,
        );
      }
      return DashboardState(
        month: month,
        summary: summary,
        trends: previous.trends,
        recent: previous.recent,
      );
    });
  }
}

DateTime _currentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// How « Épargne mensuelle » draws its months: one bar each, or joined as a line.
enum SavingsChartView { bars, line }

/// The savings chart's chosen view. Panel state held for the session: the provider lives as
/// long as the app's `ProviderScope`, so leaving the dashboard and coming back keeps the
/// choice, and a relaunch starts again on the bars. Both views draw the same series, so
/// switching re-reads nothing.
class SavingsChartViewController extends Notifier<SavingsChartView> {
  @override
  SavingsChartView build() => SavingsChartView.bars;

  void set(SavingsChartView view) => state = view;
}

final savingsChartViewProvider =
    NotifierProvider<SavingsChartViewController, SavingsChartView>(
      SavingsChartViewController.new,
    );

/// Points the transactions list at what a « Dépenses par catégorie » row
/// stands for: [categoryId] over the whole of [month]. The « Autres » fold has
/// no single category, so it clears the category and keeps the month.
void focusTransactionsOnCategory(
  TransactionFiltersNotifier filters, {
  required String? categoryId,
  required DateTime month,
}) {
  filters
    ..setCategory(categoryId)
    ..setDateRange(
      DateTime(month.year, month.month),
      DateTime(month.year, month.month + 1, 0),
    );
}
