import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_habits.dart';
import 'dashboard_controller.dart';

/// « Par rapport à vos habitudes » for the month the dashboard shows.
///
/// It follows [dashboardControllerProvider] rather than living in its state:
/// every reload of the dashboard (a month change, a refresh, an import or a
/// recategorization invalidating it) hands out a new future, so the habits
/// reload with it, and a failure here stays in its own block instead of
/// replacing the whole panel with an error. No automatic retry: the block's
/// error state offers « Réessayer ».
final dashboardHabitsProvider = FutureProvider<DashboardHabits>((ref) async {
  final dashboard = await ref.watch(dashboardControllerProvider.future);
  return ref
      .read(dashboardRepositoryProvider)
      .habits(dashboard.month, today: ref.read(dashboardTodayProvider)());
}, retry: (_, _) => null);
