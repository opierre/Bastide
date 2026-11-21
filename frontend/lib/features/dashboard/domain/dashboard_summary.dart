import 'package:flutter/foundation.dart';

/// One top-level category's slice of the month's expense total, its
/// subcategories included.
@immutable
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.hue,
    required this.amountMinor,
    required this.pct,
  });

  final String? categoryId;

  /// An i18n key for system categories, free text for user categories — see
  /// `localizedCategoryName` in the transactions feature.
  final String name;

  /// The category's hue slot as the API stores it (`cat0`–`cat6`, `income`),
  /// resolved to a colour by the theme; `cat0` for the uncategorized bucket.
  final String hue;
  final int amountMinor;
  final double pct;
}

/// One row of « Dépenses par catégorie »: a category, or the fold of the
/// smallest ones into « Autres » when there are more than
/// [DashboardSummary.maxSpendingRows].
@immutable
class SpendingRow {
  const SpendingRow({
    required this.category,
    required this.amountMinor,
    required this.pct,
    required this.barFraction,
  });

  /// The category this row stands for; `null` for the « Autres » fold.
  final CategoryBreakdown? category;

  /// Positive magnitude of what the row spent.
  final int amountMinor;

  /// Share of the month's spending, in percent.
  final double pct;

  /// The bar's length against the largest row, `0..1`.
  final double barFraction;

  bool get isOthers => category == null;
}

/// The monthly dashboard summary: totals, MoM deltas, and the expense breakdown.
///
/// `savingsRate` and the two `*DeltaPct` fields are fractions/percentages as returned by the
/// backend — `savingsRate` is a `0..1` ratio, the deltas are already
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
    this.savingsRateGoal = defaultSavingsRateGoal,
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

  /// The user's savings-rate goal as a `0..1` ratio, chosen in Paramètres →
  /// Préférences.
  final double savingsRateGoal;

  /// At most this many rows in « Dépenses par catégorie »; past it the smallest
  /// categories fold into « Autres » (`docs/design/04-dashboard.md` §3a).
  static const maxSpendingRows = 8;

  /// A month with nothing in it: the reading line shows « — » figures.
  bool get isEmpty =>
      incomeMinor == 0 && expenseMinor == 0 && byCategory.isEmpty;

  /// Whether the month has a savings rate at all. With no income there is
  /// nothing to divide by: the figure is « — » and the repère is not drawn.
  bool get hasSavingsRate => incomeMinor > 0;

  /// Whether the month met the savings goal.
  bool get savingsGoalReached =>
      hasSavingsRate && savingsRate >= savingsRateGoal;

  /// The rate's position on the repère, whose scale runs from 0 to twice the
  /// goal (`00` §8). The meter clamps the fill; a negative rate draws none.
  /// The goal is at least 1 %, so the scale is never empty.
  double get savingsRateMeterFraction =>
      (savingsRate / (savingsRateGoal * 2)).clamp(0.0, 1.0);

  /// Where the goal's mark stands on that scale: always halfway.
  static const savingsGoalMarkFraction = 0.5;

  /// The ranked rows: largest first, bars measured against the largest, and
  /// beyond [maxSpendingRows] the smallest folded into one « Autres » row so
  /// the block never runs past eight rows.
  List<SpendingRow> get rankedSpending {
    final sorted = [
      for (final category in byCategory)
        if (category.amountMinor > 0) category,
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    if (sorted.isEmpty) return const [];

    final kept = sorted.length > maxSpendingRows
        ? sorted.sublist(0, maxSpendingRows - 1)
        : sorted;
    final folded = sorted.length > maxSpendingRows
        ? sorted.sublist(maxSpendingRows - 1)
        : const <CategoryBreakdown>[];
    final foldedMinor = folded.fold<int>(0, (sum, c) => sum + c.amountMinor);
    final foldedPct = folded.fold<double>(0, (sum, c) => sum + c.pct);
    final largest = sorted.first.amountMinor > foldedMinor
        ? sorted.first.amountMinor
        : foldedMinor;

    return [
      for (final category in kept)
        SpendingRow(
          category: category,
          amountMinor: category.amountMinor,
          pct: category.pct,
          barFraction: category.amountMinor / largest,
        ),
      if (folded.isNotEmpty)
        SpendingRow(
          category: null,
          amountMinor: foldedMinor,
          pct: foldedPct,
          barFraction: foldedMinor / largest,
        ),
    ];
  }
}

/// The savings-rate goal a user has before choosing one, as a `0..1` ratio:
/// the backend's own default of 20 %.
const defaultSavingsRateGoal = 0.20;
