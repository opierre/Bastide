import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/upcoming_charges.dart';

/// « À venir »: the current month's remaining recurring charges.
///
/// Apart from `dashboardControllerProvider` because it does not follow the
/// month selector: paging the month reloads the other blocks, never this one.
/// Auto-disposed, so coming back to the dashboard reads it afresh after a
/// charge landed or a series changed in Abonnements.
final upcomingChargesProvider = FutureProvider.autoDispose<UpcomingCharges>(
  (ref) => ref.watch(dashboardRepositoryProvider).upcoming(),
);
