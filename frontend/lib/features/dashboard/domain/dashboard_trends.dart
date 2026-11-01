import 'package:flutter/foundation.dart';

/// One month's income and expense, for the income-vs-expense bars.
@immutable
class MonthlyTotals {
  const MonthlyTotals({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.netMinor,
  });

  /// First of the month.
  final DateTime month;
  final int incomeMinor;

  /// Positive magnitude, matching [DashboardSummary.expenseMinor].
  final int expenseMinor;
  final int netMinor;
}

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

/// The dashboard's two trend series.
///
/// Both windows end at the *current* month rather than the selected one — they answer "how am
/// I trending lately", which doesn't change when the user pages the month picker back. That is
/// why they arrive from their own endpoint and are fetched once per session rather than per
/// month.
@immutable
class DashboardTrends {
  const DashboardTrends({
    required this.monthlySeries,
    required this.savingsSeries,
    required this.currency,
  });

  /// The last 4 months ending with the current one, oldest first.
  final List<MonthlyTotals> monthlySeries;

  /// The last 12 months ending with the current one, oldest first.
  final List<SavingsPoint> savingsSeries;
  final String currency;

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

/// One row of « Activité récente ».
///
/// A flattened view rather than the transactions feature's `Transaction`: this row shows only
/// a label, its account, a date and an amount, and the account *name* is resolved here so the
/// widget never has to hold an id-to-name map (see the flutter-frontend skill's no-logic-in-
/// widgets rule).
@immutable
class RecentTransaction {
  const RecentTransaction({
    required this.id,
    required this.label,
    required this.accountLabel,
    required this.bookedDate,
    required this.amountMinor,
    required this.currency,
  });

  final String id;

  /// The merchant if there is one, else the cleaned description.
  final String label;

  /// « BNP — Compte courant »: the institution and the account it holds.
  final String accountLabel;
  final DateTime bookedDate;
  final int amountMinor;
  final String currency;
}
