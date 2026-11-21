import 'package:flutter/foundation.dart';

import '../../../core/logos/logo_ref.dart';

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
    this.logo,
    this.isRawLabel = false,
  });

  final String id;

  /// The merchant if there is one, else the cleaned description.
  final String label;

  /// « BNP Compte courant »: the institution and the account it holds.
  final String accountLabel;
  final DateTime bookedDate;
  final int amountMinor;
  final String currency;

  /// The rule logo the chip shows instead of the monogram; `null` for none.
  final LogoRef? logo;

  /// Whether [label] is the bank's raw description rather than a recognised
  /// merchant: set in Geist Mono, behind the « ? » monogram (`00` §7).
  final bool isRawLabel;
}
