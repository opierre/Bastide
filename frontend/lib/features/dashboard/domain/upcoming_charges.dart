import 'package:flutter/foundation.dart';

import '../../../core/logos/logo_ref.dart';

/// One row of « À venir »: a charge still due this month, or a missed one.
///
/// Sealed so the row widget switches on what it is rather than on loose
/// nullable fields: a due charge carries its date and maybe a price rise, a
/// missed one the date it was expected on.
@immutable
sealed class UpcomingRow {
  const UpcomingRow({
    required this.seriesId,
    required this.label,
    required this.amountMinor,
    required this.logo,
  });

  final String seriesId;
  final String label;

  /// Signed, like every other amount on the wire.
  final int amountMinor;

  /// The rule logo the series shows; `null` for the monogram.
  final LogoRef? logo;
}

/// A charge expected between today and the end of the month.
@immutable
class UpcomingDue extends UpcomingRow {
  const UpcomingDue({
    required super.seriesId,
    required super.label,
    required super.amountMinor,
    required super.logo,
    required this.dueOn,
    this.priceIncreaseMinor,
  });

  final DateTime dueOn;

  /// Signed step of a recent price rise, negative on an outflow that grew;
  /// `null` when the price has not risen recently (Abonnements « Hausse »).
  final int? priceIncreaseMinor;
}

/// A charge overdue past its tolerance (Abonnements « Prélèvement manquant »).
@immutable
class UpcomingMissed extends UpcomingRow {
  const UpcomingMissed({
    required super.seriesId,
    required super.label,
    required super.amountMinor,
    required super.logo,
    required this.expectedOn,
  });

  final DateTime expectedOn;
}

/// `GET /recurring/upcoming`: what the active series will still charge this
/// month (`docs/design/04-dashboard.md` §5c). Always the current month,
/// whatever month the dashboard shows.
@immutable
class UpcomingCharges {
  const UpcomingCharges({
    required this.through,
    required this.totalMinor,
    required this.due,
    required this.missed,
    required this.currency,
  });

  /// The most rows the block shows.
  static const maxRows = 4;

  /// The last day of the current month.
  final DateTime through;

  /// Every due charge summed, server-side, signed. Missed charges are left
  /// out; due charges the row limit drops still count.
  final int totalMinor;

  /// Soonest first.
  final List<UpcomingDue> due;

  /// Oldest first.
  final List<UpcomingMissed> missed;

  final String currency;

  /// Whether there is anything to show; the block is hidden otherwise.
  bool get isEmpty => due.isEmpty && missed.isEmpty;

  /// The rows the block draws: due charges by date, then missed ones, at most
  /// [maxRows]. Past the limit the latest due charges go first, so a missed
  /// charge is never pushed out by a routine one.
  List<UpcomingRow> get rows {
    final shownMissed = missed.take(maxRows).toList();
    return [...due.take(maxRows - shownMissed.length), ...shownMissed];
  }
}
