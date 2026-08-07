import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import '../domain/dashboard_trends.dart';

/// The selected month alongside the summary loaded for it, plus the trend series.
///
/// The month is always the first of that month. [trends] is *not* keyed to it: both its windows
/// end at the current calendar month, so paging the picker back leaves the bars and the savings
/// line where they are (see `PROJECT.md` §5).
@immutable
class DashboardState {
  const DashboardState({
    required this.month,
    required this.summary,
    required this.trends,
  });

  final DateTime month;
  final DashboardSummary summary;
  final DashboardTrends trends;

  DashboardState copyWith({DateTime? month, DashboardSummary? summary}) => DashboardState(
    month: month ?? this.month,
    summary: summary ?? this.summary,
    trends: trends,
  );
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
    final (summary, trends) = await (repository.summary(month), repository.trends()).wait;
    return DashboardState(month: month, summary: summary, trends: trends);
  }

  Future<void> changeMonth(DateTime month) => _load(month);

  Future<void> refresh() {
    final current = state.value;
    return _load(current?.month ?? _currentMonth(), reloadTrends: true);
  }

  /// Reloads the summary for [month]. The trends are re-fetched only on an explicit refresh:
  /// they don't depend on the month, so paging the picker would otherwise re-request a series
  /// that cannot have changed.
  Future<void> _load(DateTime month, {bool reloadTrends = false}) async {
    final previous = state.value;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(dashboardRepositoryProvider);
      final summary = await repository.summary(month);
      final trends = reloadTrends || previous == null
          ? await repository.trends()
          : previous.trends;
      return DashboardState(month: month, summary: summary, trends: trends);
    });
  }
}

DateTime _currentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(DashboardController.new);
