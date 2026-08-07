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

/// One point on the cumulative-savings line.
@immutable
class SavingsPoint {
  const SavingsPoint({required this.month, required this.cumulativeMinor});

  /// First of the month.
  final DateTime month;

  /// Running total of net through this month, including months before the returned window.
  final int cumulativeMinor;
}

/// The dashboard's two trend series.
///
/// Both windows end at the *current* month rather than the selected one — they answer "how am
/// I trending lately", which doesn't change when the user pages the month picker back. That is
/// why they arrive from their own endpoint and are fetched once per session rather than per
/// month (see `PROJECT.md` §5).
@immutable
class DashboardTrends {
  const DashboardTrends({
    required this.monthlySeries,
    required this.savingsSeries,
    required this.currency,
  });

  /// The last 4 months ending with the current one, oldest first.
  final List<MonthlyTotals> monthlySeries;

  /// The last 6 months ending with the current one, oldest first.
  final List<SavingsPoint> savingsSeries;
  final String currency;

  /// The latest cumulative total — the savings card's headline figure.
  int get totalSavedMinor =>
      savingsSeries.isEmpty ? 0 : savingsSeries.last.cumulativeMinor;

  /// How much the latest month added, i.e. the last step of the line. This is the *month's*
  /// net rather than a recomputed difference, so it matches the net card exactly.
  int get latestMonthNetMinor {
    if (savingsSeries.isEmpty) return 0;
    if (savingsSeries.length == 1) return savingsSeries.single.cumulativeMinor;
    return savingsSeries.last.cumulativeMinor -
        savingsSeries[savingsSeries.length - 2].cumulativeMinor;
  }

  /// The month the latest point covers — « +635,65 € en mai ».
  DateTime? get latestMonth => savingsSeries.isEmpty ? null : savingsSeries.last.month;
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
