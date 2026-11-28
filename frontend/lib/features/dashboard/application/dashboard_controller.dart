import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';

/// The selected month alongside the summary and the savings series loaded for it.
///
/// The month is always the first of that month. [trends] ends on it, so paging the picker
/// back moves the savings chart's window with it.
@immutable
class DashboardState {
  const DashboardState({
    required this.month,
    required this.summary,
    required this.trends,
    required this.hasTransactions,
  });

  final DateTime month;
  final DashboardSummary summary;
  final DashboardTrends trends;

  /// Whether the user has any transaction at all. Without one the panel shows
  /// its empty state; a month without data still draws the panel with « — ».
  /// Not keyed to [month]: a month change cannot alter it.
  final bool hasTransactions;
}

/// Loads the dashboard summary for a selected month, defaulting to the latest month with data.
/// Month changes and the initial load both flow through this one controller — see
/// `TransactionsController` for the split-provider alternative, which isn't needed here since
/// there's only one axis of state (the month) rather than a whole filter set.
class DashboardController extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final repository = ref.read(dashboardRepositoryProvider);
    final latest = await repository.latestMonthWithData();
    final month = latest ?? _currentMonth();
    // Independent of each other, so they go out together rather than in series.
    final (summary, trends) = await (
      repository.summary(month),
      repository.trends(month, currentMonth: _currentMonth()),
    ).wait;
    return DashboardState(
      month: month,
      summary: summary,
      trends: trends,
      hasTransactions: latest != null,
    );
  }

  Future<void> changeMonth(DateTime month) => _load(month);

  /// Re-reads the summary of the month on display, after something it carries
  /// changed elsewhere (the savings-rate goal, in Préférences).
  Future<void> reloadSummary() {
    final current = state.value;
    return _load(current?.month ?? _currentMonth());
  }

  Future<void> refresh() {
    final current = state.value;
    return _load(current?.month ?? _currentMonth(), recheckData: true);
  }

  /// Reloads the summary and the savings series for [month]. Whether the user has any
  /// transaction is re-read only on an explicit refresh: it doesn't depend on the month, so
  /// paging the picker would otherwise re-request an answer that cannot have changed.
  Future<void> _load(DateTime month, {bool recheckData = false}) async {
    final previous = state.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(dashboardRepositoryProvider);
      final currentMonth = _currentMonth();
      // The summary goes first and alone, so its failure (a bad month) surfaces as itself
      // rather than wrapped in a `ParallelWaitError`.
      final summary = await repository.summary(month);
      if (recheckData || previous == null) {
        final (trends, latest) = await (
          repository.trends(month, currentMonth: currentMonth),
          repository.latestMonthWithData(),
        ).wait;
        return DashboardState(
          month: month,
          summary: summary,
          trends: trends,
          hasTransactions: latest != null,
        );
      }
      final trends = await repository.trends(month, currentMonth: currentMonth);
      return DashboardState(
        month: month,
        summary: summary,
        trends: trends,
        hasTransactions: previous.hasTransactions,
      );
    });
  }

  DateTime _currentMonth() {
    final now = ref.read(dashboardTodayProvider)();
    return DateTime(now.year, now.month);
  }
}

/// "Today" for the dashboard: the month it opens on when there is no data yet, and the month
/// in progress the savings chart hatches. A provider so tests can pin the clock.
final dashboardTodayProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
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
    ..clearImport()
    ..setCategory(categoryId)
    ..setDateRange(
      DateTime(month.year, month.month),
      DateTime(month.year, month.month + 1, 0),
    );
}
