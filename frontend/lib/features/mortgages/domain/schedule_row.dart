import 'package:flutter/foundation.dart';

import 'mortgage.dart';

/// One instalment, exactly as the engine produced it.
@immutable
class ScheduleRow {
  const ScheduleRow({
    required this.ordinal,
    required this.dueOn,
    required this.instalmentMinor,
    required this.interestMinor,
    required this.principalMinor,
    required this.insuranceMinor,
    required this.outstandingAfterMinor,
  });

  final int ordinal;
  final DateTime dueOn;

  /// Interest, principal and insurance together — the « Total versé » column.
  final int instalmentMinor;
  final int interestMinor;
  final int principalMinor;

  /// Kept apart from interest and principal: folding it into either misstates
  /// both the cost and the payoff.
  final int insuranceMinor;
  final int outstandingAfterMinor;
}

/// One calendar year of a loan's schedule — the table's page.
///
/// The foot figures come from the API: [interestMinor], [principalMinor] and
/// [insuranceMinor] are the window totals, [instalmentMinor] and
/// [outstandingAtYearEndMinor] the same window at yearly granularity. Nothing
/// is summed in Dart.
@immutable
class ScheduleYear {
  const ScheduleYear({
    required this.year,
    required this.rows,
    required this.interestMinor,
    required this.principalMinor,
    required this.insuranceMinor,
    required this.instalmentMinor,
    required this.outstandingAtYearEndMinor,
    required this.currency,
  });

  final int year;
  final List<ScheduleRow> rows;
  final int interestMinor;
  final int principalMinor;
  final int insuranceMinor;
  final int instalmentMinor;
  final int outstandingAtYearEndMinor;
  final String currency;
}

/// The calendar years a loan's schedule spans, and where the table opens.
///
/// Date bookkeeping only — which year, which month — never an amount.
@immutable
class ScheduleYears {
  const ScheduleYears({
    required this.mortgageId,
    required this.firstYear,
    required this.lastYear,
    required this.currentInstalmentMonth,
  });

  /// Derived from the loan's own dates as of [today].
  ///
  /// The current instalment is the latest one due on or before today: the month
  /// before `next_payment_on`, the last one once the schedule has run out, and
  /// none before the first payment.
  factory ScheduleYears.of(MortgageDetail detail, DateTime today) {
    final mortgage = detail.mortgage;
    final first = mortgage.firstPaymentDate;
    final day = DateTime(today.year, today.month, today.day);

    final DateTime? current;
    if (day.isBefore(first)) {
      current = null;
    } else if (mortgage.nextPaymentOn case final next?) {
      current = DateTime(next.year, next.month - 1);
    } else {
      current = DateTime(detail.lastPaymentOn.year, detail.lastPaymentOn.month);
    }

    return ScheduleYears(
      mortgageId: mortgage.id,
      firstYear: first.year,
      lastYear: detail.lastPaymentOn.year,
      currentInstalmentMonth: current,
    );
  }

  final String mortgageId;
  final int firstYear;
  final int lastYear;

  /// First day of the current instalment's month; `null` before the first one.
  final DateTime? currentInstalmentMonth;

  /// The year the table opens on.
  int get openingYear => currentInstalmentMonth?.year ?? firstYear;

  int get yearCount => lastYear - firstYear + 1;

  /// « Année 4 sur 25 » — 1-based.
  int positionOf(int year) => year - firstYear + 1;

  int clamp(int year) => year.clamp(firstYear, lastYear);

  bool isCurrentInstalment(ScheduleRow row) {
    final current = currentInstalmentMonth;
    return current != null &&
        row.dueOn.year == current.year &&
        row.dueOn.month == current.month;
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleYears &&
      other.mortgageId == mortgageId &&
      other.firstYear == firstYear &&
      other.lastYear == lastYear &&
      other.currentInstalmentMonth == currentInstalmentMonth;

  @override
  int get hashCode =>
      Object.hash(mortgageId, firstYear, lastYear, currentInstalmentMonth);
}
