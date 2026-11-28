import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/application/goals_controller.dart';
import '../../goals/domain/goal.dart';
import '../domain/upcoming_charges.dart';
import 'upcoming_charges_provider.dart';

/// How the dashboard's bottom band shares its width
/// (`docs/design/04-dashboard.md`, « États »): « Par rapport à vos
/// habitudes » holds the left half; « Objectifs » and « À venir » split the
/// right half, one of them takes it whole when the other is hidden, and the
/// habits block takes the full width when both are.
enum DashboardBandLayout {
  /// Habits on the left; compact « Objectifs » beside « À venir » on the right.
  goalsAndUpcoming,

  /// Habits on the left; « Objectifs » alone on the right, in one-line rows.
  goalsOnly,

  /// Habits on the left; « À venir » alone on the right.
  upcomingOnly,

  /// Habits across the full width.
  habitsOnly,
}

/// What the side blocks of the bottom band have to show.
@immutable
class DashboardBand {
  const DashboardBand({required this.goals, required this.upcoming});

  /// Up to four active goals by creation order; empty hides « Objectifs ».
  final List<Goal> goals;

  /// The charges still due this month; `null` hides « À venir ».
  final UpcomingCharges? upcoming;

  DashboardBandLayout get layout =>
      switch ((goals.isNotEmpty, upcoming != null)) {
        (true, true) => DashboardBandLayout.goalsAndUpcoming,
        (true, false) => DashboardBandLayout.goalsOnly,
        (false, true) => DashboardBandLayout.upcomingOnly,
        (false, false) => DashboardBandLayout.habitsOnly,
      };
}

/// The bottom band's side blocks. A goals or upcoming load that has not
/// landed or has failed hides its block rather than putting an error about a
/// side section on the dashboard; « À venir » also stays away while there is
/// no charge left to show this month, or no recurring series at all.
final dashboardBandProvider = Provider.autoDispose<DashboardBand>((ref) {
  final goals =
      ref.watch(goalsControllerProvider).value?.topGoals ?? const <Goal>[];
  final upcoming = ref.watch(upcomingChargesProvider).value;
  return DashboardBand(
    goals: goals,
    upcoming: upcoming == null || upcoming.isEmpty ? null : upcoming,
  );
});
