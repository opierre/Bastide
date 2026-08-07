import 'dart:async';

import 'package:finstride/core/navigation/sidebar_controller.dart';
import 'package:finstride/features/dashboard/application/dashboard_controller.dart';

/// A no-network `DashboardController` double for widget tests: holds a fixed state without
/// touching the real API client — see `fake_transactions_controller.dart` for the same pattern.
class FakeDashboardController extends DashboardController {
  FakeDashboardController({required this.initialState});

  final DashboardState initialState;

  final changeMonthCalls = <DateTime>[];

  @override
  Future<DashboardState> build() async => initialState;

  @override
  Future<void> changeMonth(DateTime month) async {
    changeMonthCalls.add(month);
  }
}

/// A controller that never resolves, so the screen stays on its loading branch.
class FakeLoadingDashboardController extends DashboardController {
  @override
  Future<DashboardState> build() => Completer<DashboardState>().future;
}

/// The sidebar already collapsed, for the panel's « nav réduite » state.
class FakeCollapsedSidebar extends SidebarCollapsed {
  @override
  bool build() => true;
}
