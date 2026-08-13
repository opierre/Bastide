import 'package:flutter/foundation.dart';

/// One month's expense split, as the API reports it: a positive magnitude per
/// category id, plus the total those magnitudes are a share of.
///
/// Only expenses — the backend's breakdown excludes income and transfers (see
/// `PROJECT.md` §5) — so an income category simply has no entry here rather than
/// an amount of zero. The two are different answers and the panel renders them
/// the same way, but nothing in this model invents a figure for the first.
///
/// The uncategorized bucket the endpoint returns under a `null` id is dropped:
/// it has no row in the category tree to sit on.
@immutable
class MonthlySpend {
  const MonthlySpend({
    required this.month,
    required this.currency,
    required this.totalMinor,
    required this.byCategoryId,
  });

  /// The first of the month the figures cover.
  final DateTime month;
  final String currency;

  /// The month's whole expense total — the denominator every share is taken
  /// against, and larger than the sum of [byCategoryId] whenever some of the
  /// month's spending is still uncategorized.
  final int totalMinor;

  /// Category id → positive expense magnitude in minor units, exactly as
  /// recorded: subcategory amounts are *not* folded into their parent here.
  /// That roll-up needs the tree, so it happens in the application layer.
  final Map<String, int> byCategoryId;
}

/// What one category row shows: what it cost this month, and what share of the
/// month that is.
@immutable
class CategorySpend {
  const CategorySpend({required this.amountMinor, required this.pct});

  /// Positive expense magnitude. For a parent, its own transactions plus every
  /// subcategory's — the parent row stands for the whole group.
  final int amountMinor;

  /// Share of the month's total expense, as a percentage (`0..100`), matching
  /// the dashboard breakdown's `pct`.
  final double pct;

  /// The bar's fill, as a `0..1` fraction of its track.
  double get fraction => (pct / 100).clamp(0.0, 1.0);
}

/// The month's spend arranged the way the panel reads it: one entry per
/// category that spent anything, parents carrying their subcategories' totals.
@immutable
class CategorySpendView {
  const CategorySpendView({
    required this.month,
    required this.currency,
    required this.byCategoryId,
  });

  final DateTime month;
  final String currency;

  /// Absent for a category that spent nothing this month — which is the honest
  /// shape, since "no expense rows" and "an expense of zero" are the same fact
  /// only by accident.
  final Map<String, CategorySpend> byCategoryId;

  CategorySpend? forCategory(String id) => byCategoryId[id];
}
