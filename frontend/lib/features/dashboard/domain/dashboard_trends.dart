import 'package:flutter/foundation.dart';

/// One month on the savings chart.
@immutable
class SavingsPoint {
  const SavingsPoint({required this.month, required this.savedMinor});

  /// First of the month.
  final DateTime month;

  /// What the month put aside — its own net, not a running total. Negative when it spent
  /// more than it earned.
  final int savedMinor;
}

/// The dashboard's savings series.
///
/// The window ends on the month selected on the dashboard, so paging the month picker back
/// shows the year leading up to that month.
@immutable
class DashboardTrends {
  const DashboardTrends({
    required this.savingsSeries,
    required this.currency,
    this.currentMonth,
  });

  /// The 12 months ending with the selected one, oldest first.
  final List<SavingsPoint> savingsSeries;
  final String currency;

  /// The calendar month when the series was read (first of the month), or `null` when
  /// unknown. The month in progress is not yet a fact, so the chart hatches it, and only it.
  final DateTime? currentMonth;

  /// The indexes in [savingsSeries] of the month in progress: one when [currentMonth] falls
  /// inside the window, none when the window ends before it.
  Set<int> get inProgress {
    final current = currentMonth;
    if (current == null) return const {};
    return {
      for (var i = 0; i < savingsSeries.length; i++)
        if (savingsSeries[i].month.year == current.year &&
            savingsSeries[i].month.month == current.month)
          i,
    };
  }

  /// How many months the savings average spans at most: a year, so a seasonal month (a
  /// bonus, a holiday) is weighed against the rest of the year rather than its neighbours.
  static const averageWindowMonths = 12;

  /// The months [averageSavedMinor] averages: the last [averageWindowMonths] of
  /// [savingsSeries], or all of them for a newer user with less history.
  List<SavingsPoint> get averageWindow =>
      savingsSeries.length <= averageWindowMonths
      ? savingsSeries
      : savingsSeries.sublist(savingsSeries.length - averageWindowMonths);

  /// What the window's months put aside on average — the savings card's headline and the
  /// chart's dotted reference line. The current month counts as it stands, as its bar does.
  ///
  /// Rounded to the nearest minor unit, halves away from zero (so `-0.5` → `-1`, as `0.5` →
  /// `1`), in integer arithmetic: money stays an integer even when the mean isn't, and no
  /// float ever holds the total.
  int get averageSavedMinor {
    final window = averageWindow;
    if (window.isEmpty) return 0;
    final total = window.fold<int>(0, (sum, p) => sum + p.savedMinor);
    final count = window.length;
    final quotient = total ~/ count;
    final remainder = total.remainder(count);
    return remainder.abs() * 2 >= count ? quotient + total.sign : quotient;
  }
}
