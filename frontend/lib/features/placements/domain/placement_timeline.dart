import 'package:flutter/foundation.dart';

import 'investment.dart';

/// The placement at one date of its history: what the chart draws and its
/// hover card reads (`17-placements.md` §Inspector 5).
@immutable
class TimelinePoint {
  const TimelinePoint({
    required this.date,
    required this.valueMinor,
    required this.netPaymentsMinor,
    required this.declared,
  });

  final DateTime date;

  /// The last value declared on or before [date]; `null` before the first.
  /// Between two declarations it is held flat: the app knows no price.
  final int? valueMinor;

  /// Every movement up to and including [date], added.
  final int netPaymentsMinor;

  /// A value was declared on [date]: the chart puts a dot on it.
  final bool declared;
}

/// The dated history of one placement, one point per date something
/// happened, from its opening to [end] (today, or the closing date).
///
/// Only the dates the user wrote down appear, plus the opening and the end,
/// so the chart never makes up a point between them.
List<TimelinePoint> placementTimeline(InvestmentDetail detail, DateTime end) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

  final investment = detail.investment;
  final last = day(investment.closedOn ?? end);
  final movements = [...detail.movements]
    ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
  final valuations = [...detail.valuations]
    ..sort((a, b) => a.valuedOn.compareTo(b.valuedOn));
  final dates = <DateTime>{
    day(investment.openedOn),
    for (final movement in movements) day(movement.occurredOn),
    for (final valuation in valuations) day(valuation.valuedOn),
    last,
  }.where((date) => !date.isAfter(last)).toList()..sort();

  final points = <TimelinePoint>[];
  var net = 0;
  var m = 0;
  var v = 0;
  int? value;
  for (final date in dates) {
    while (m < movements.length &&
        !day(movements[m].occurredOn).isAfter(date)) {
      net += movements[m].amountMinor;
      m++;
    }
    var declared = false;
    while (v < valuations.length &&
        !day(valuations[v].valuedOn).isAfter(date)) {
      value = valuations[v].valueMinor;
      declared = day(valuations[v].valuedOn) == date;
      v++;
    }
    points.add(
      TimelinePoint(
        date: date,
        valueMinor: value,
        netPaymentsMinor: net,
        declared: declared,
      ),
    );
  }
  return points;
}
