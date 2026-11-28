import 'package:flutter/foundation.dart';

/// Which way a category's month moved against its average.
enum HabitTrend { rise, fall, flat }

/// One row of « Par rapport à vos habitudes »: a top-level category's
/// spending in the month against its own monthly average
/// (`docs/design/04-dashboard.md` §5a).
@immutable
class CategoryHabit {
  const CategoryHabit({
    required this.categoryId,
    required this.name,
    required this.hue,
    required this.amountMinor,
    required this.averageMinor,
    required this.gapMinor,
  });

  /// `null` for the uncategorized bucket.
  final String? categoryId;

  /// An i18n key for system categories, free text for user categories, as in
  /// `CategoryBreakdown.name`.
  final String name;

  /// The hue slot as the API stores it, as in `CategoryBreakdown.hue`.
  final String hue;

  /// The month's spending, a positive magnitude.
  final int amountMinor;

  /// Mean monthly spending over the months counted, a positive magnitude;
  /// `null` when the category had no spending in them.
  final int? averageMinor;

  /// `amountMinor − averageMinor`, positive when the month spent more than
  /// usual; `null` with no average.
  final int? gapMinor;

  /// Whether the category had spending in the months counted. Without it the
  /// row draws no repère and no gap.
  bool get hasHistory => averageMinor != null && averageMinor! > 0;

  /// The month's position on the repère, whose scale runs from 0 to twice the
  /// average, so the average's mark sits halfway on every row.
  double get meterFraction =>
      hasHistory ? (amountMinor / (averageMinor! * 2)).clamp(0.0, 1.0) : 0;

  /// Where the average's mark stands on that scale.
  static const averageMarkFraction = 0.5;

  /// Whether the month reached 120 % of the average, which fills the repère
  /// `over`. Integer arithmetic, so 120 % exactly is over and no rounding
  /// moves the threshold.
  bool get isOver => hasHistory && amountMinor * 5 >= averageMinor! * 6;

  HabitTrend get trend => switch (gapMinor ?? 0) {
    > 0 => HabitTrend.rise,
    < 0 => HabitTrend.fall,
    _ => HabitTrend.flat,
  };
}

/// « Par rapport à vos habitudes » for one month.
@immutable
class DashboardHabits {
  const DashboardHabits({
    required this.month,
    required this.monthsCounted,
    required this.rows,
    required this.totalGapMinor,
    required this.currency,
    this.daysElapsed,
  });

  /// The first of the month the habits read.
  final DateTime month;

  /// When [month] is the month in progress, how many of its days have passed,
  /// today included; `null` for an earlier month. The block then says the
  /// month's spending so far is read against full-month averages.
  final int? daysElapsed;

  bool get isInProgress => daysElapsed != null;

  /// How many months the averages cover: 12 in the usual case, fewer for a
  /// recent user, 0 when there is no earlier month of data.
  final int monthsCounted;

  /// Every category with spending in the month, as the API orders them: rows
  /// with a gap first, largest gap first, then the rows without history.
  final List<CategoryHabit> rows;

  /// The sum of the gaps of every row that has an average, rows past the
  /// limit included; `null` when no row has one, and the heading then shows
  /// no total.
  final int? totalGapMinor;
  final String currency;

  /// At most this many rows; the smallest gaps are left out (`04` §5a).
  static const maxRows = 8;

  /// The rows the block draws: the API's order already puts the largest gaps
  /// first and the rows without history last, so the cut keeps the largest.
  List<CategoryHabit> get shownRows =>
      rows.length > maxRows ? rows.sublist(0, maxRows) : rows;
}
