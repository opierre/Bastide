import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';

/// The selected month alongside the summary loaded for it, plus the trend series.
///
/// The month is always the first of that month. [trends] is *not* keyed to it: both its windows
/// end at the current calendar month, so paging the picker back leaves the bars and the savings
/// line where they are.
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
