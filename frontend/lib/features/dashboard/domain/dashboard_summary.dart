import 'package:flutter/foundation.dart';

/// One category's slice of the month's expense total.
@immutable
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.amountMinor,
    required this.pct,
  });

  final String? categoryId;

  /// An i18n key for system categories, free text for user categories — see
  /// `localizedCategoryName` in the transactions feature.
  final String name;
  final int amountMinor;
  final double pct;
}

/// The monthly dashboard summary: totals, MoM deltas, and the expense breakdown.
///
/// `savingsRate` and the two `*DeltaPct` fields are fractions/percentages as returned by the
/// backend (see `PROJECT.md` §5) — `savingsRate` is a `0..1` ratio, the deltas are already
/// percentages. Formatting happens only in the presentation layer.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.netMinor,
    required this.savingsRate,
    required this.incomeDeltaPct,
    required this.expenseDeltaPct,
    required this.netDeltaPct,
    required this.savingsRateDeltaPct,
    required this.byCategory,
    required this.currency,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int netMinor;
  final double savingsRate;
  final double incomeDeltaPct;
  final double expenseDeltaPct;
  final double netDeltaPct;

  /// MoM change in [savingsRate], in percentage points (already `×100` — see the backend schema).
  final double savingsRateDeltaPct;
  final List<CategoryBreakdown> byCategory;
  final String currency;

  bool get isEmpty =>
      incomeMinor == 0 && expenseMinor == 0 && byCategory.isEmpty;

  /// Whether the month met the savings goal — decides which of the two goal captions the
  /// savings card shows. Lives here rather than in the widget so the threshold comparison
  /// isn't business logic sitting in presentation.
  bool get savingsGoalReached => savingsRate >= savingsRateGoal;
}

/// The savings-rate goal the dashboard measures against, as a `0..1` ratio.
///
/// A fixed 20 % (see `docs/design/04-dashboard.md` — « Objectif : 20 % »), not a
/// per-user setting.
const savingsRateGoal = 0.20;
