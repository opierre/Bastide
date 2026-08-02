import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

/// The selected month (always the first of that month) alongside the summary loaded for it.
@immutable
class DashboardState {
  const DashboardState({required this.month, required this.summary});

  final DateTime month;
  final DashboardSummary summary;
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
    final summary = await repository.summary(month);
    return DashboardState(month: month, summary: summary);
  }

  Future<void> changeMonth(DateTime month) => _load(month);

  Future<void> refresh() {
    final current = state.value;
    return _load(current?.month ?? _currentMonth());
  }

  Future<void> _load(DateTime month) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final summary = await ref.read(dashboardRepositoryProvider).summary(month);
      return DashboardState(month: month, summary: summary);
    });
  }
}

DateTime _currentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(DashboardController.new);
