import 'package:flutter/foundation.dart';

import 'recurring_series.dart';

/// The soonest charge ahead — « Netflix — demain · 15,49 € · 15/05/2026 ».
@immutable
class NextCharge {
  const NextCharge({
    required this.seriesId,
    required this.label,
    required this.amountMinor,
    required this.dueOn,
  });

  final String seriesId;
  final String label;

  /// Signed, like every other amount on the wire.
  final int amountMinor;
  final DateTime dueOn;
}

/// A recent price rise on a series.
@immutable
class PriceIncrease {
  const PriceIncrease({
    required this.seriesId,
    required this.deltaMinor,
    required this.changedAt,
  });

  final String seriesId;

  /// Signed step, so negative on an outflow that grew.
  final int deltaMinor;
  final DateTime changedAt;
}

/// A charge that has not landed long enough after its due date to report.
@immutable
class MissedCharge {
  const MissedCharge({
    required this.seriesId,
    required this.expectedOn,
    required this.daysLate,
  });

  final String seriesId;
  final DateTime expectedOn;

  /// Server-measured, not derived from the client's clock: the panel prints
  /// « 9 jours de retard », and two clocks disagreeing would make the row say
  /// something the summary card does not.
  final int daysLate;
}

/// `GET /recurring/summary` — the three summary cards, plus the signals the
/// rows carry.
///
/// Every figure here is computed server-side and is *never* re-derived from the
/// list: the burden, the counts, and the exclusions can then never disagree
/// with each other (`PROJECT.md` §12).
@immutable
class RecurringSummary {
  const RecurringSummary({
    required this.monthlyTotalMinor,
    required this.activeCount,
    required this.cancelledCount,
    required this.cadenceCounts,
    required this.nextCharge,
    required this.priceIncreases,
    required this.missed,
    required this.currency,
  });

  /// Every running series normalised to a monthly figure and summed. Signed, so
  /// negative; cancelled and dismissed series are excluded, and so are
  /// irregular ones, which have no period to normalise from.
  final int monthlyTotalMinor;

  final int activeCount;
  final int cancelledCount;

  /// One entry per cadence, zeros included, over the same set as [activeCount].
  final Map<Cadence, int> cadenceCounts;

  final NextCharge? nextCharge;
  final List<PriceIncrease> priceIncreases;
  final List<MissedCharge> missed;
  final String currency;
}

/// What a row's Statut cell reports, if anything.
///
/// A sealed hierarchy rather than an enum plus loose fields: each signal
/// carries its own evidence — a delta and its date, a due date and its
/// lateness — and the row renders that evidence, not just the fact.
@immutable
sealed class SeriesSignal {
  const SeriesSignal();
}

/// The series got more expensive, recently enough to still be news.
@immutable
class PriceIncreaseSignal extends SeriesSignal {
  const PriceIncreaseSignal({
    required this.previousAmountMinor,
    required this.currentAmountMinor,
    required this.changedAt,
  });

  final int previousAmountMinor;
  final int currentAmountMinor;
  final DateTime changedAt;
}

/// The charge is overdue past the cadence's own tolerance.
@immutable
class MissedChargeSignal extends SeriesSignal {
  const MissedChargeSignal({required this.expectedOn, required this.daysLate});

  final DateTime expectedOn;
  final int daysLate;
}

/// The user ended the subscription. It stays listed — dimmed — because a
/// cancelled subscription is still part of the history the user is reading.
@immutable
class CancelledSignal extends SeriesSignal {
  const CancelledSignal({required this.lastChargeOn});

  final DateTime lastChargeOn;
}

/// One table row: a series and whatever the summary has to say about it.
///
/// Assembled in the controller rather than in the row widget, so the join
/// between the list and the summary's signal lists is state, not presentation
/// (see the flutter-frontend skill's no-logic-in-widgets rule).
@immutable
class SubscriptionRow {
  const SubscriptionRow({required this.series, required this.signal});

  final RecurringSeries series;

  /// `null` for a healthy subscription — the Statut cell is then empty, with no
  /// "OK" pill (`docs/design/10` §Notes).
  final SeriesSignal? signal;
}
