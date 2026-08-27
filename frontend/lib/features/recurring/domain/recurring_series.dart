import 'package:flutter/foundation.dart';

/// How often a series is charged. Mirrors the backend's `Cadence` literal
/// (`backend/app/features/recurring/schemas.py`).
///
/// [irregular] is user-declared only: the detector emits a series when it
/// recognises a rhythm and nothing otherwise, so it never produces one
/// (`PROJECT.md` §12). The manual-creation form is the only place it can be
/// chosen.
enum Cadence {
  weekly(52),
  monthly(12),
  quarterly(4),
  yearly(1),

  /// No period, so no yearly count: a series with no rhythm has no annual
  /// figure, and inventing one would put a number the user never agreed to on
  /// the screen.
  irregular(null);

  const Cadence(this.occurrencesPerYear);

  /// How many charges a year this cadence produces — the multiplier behind the
  /// annualised impact of a price change.
  final int? occurrencesPerYear;

  static Cadence fromWire(String value) =>
      Cadence.values.firstWhere((cadence) => cadence.name == value);

  String get wireValue => name;
}

/// Lifecycle of a series. Mirrors the backend's `SeriesStatus` literal.
enum SeriesStatus {
  detected,
  confirmed,
  dismissed,
  cancelled;

  static SeriesStatus fromWire(String value) =>
      SeriesStatus.values.firstWhere((status) => status.name == value);

  String get wireValue => name;
}

/// The lifecycle matrix, transcribed from `LEGAL_TRANSITIONS` in
/// `backend/app/features/recurring/service.py`.
///
/// Held here so the kebab can offer only the transitions that exist. The
/// backend still checks — this map keeps the UI from *offering* a 409, it does
/// not replace the guarantee that produces one.
const legalSeriesTransitions = <SeriesStatus, List<SeriesStatus>>{
  SeriesStatus.detected: [SeriesStatus.confirmed, SeriesStatus.dismissed],
  SeriesStatus.confirmed: [SeriesStatus.cancelled, SeriesStatus.dismissed],
  SeriesStatus.cancelled: [SeriesStatus.confirmed],
  SeriesStatus.dismissed: [],
};

/// A recurring series as returned by `GET /recurring`.
///
/// `merchant_key` is deliberately absent, exactly as it is on the wire: it is
/// the machine key the detector groups on, not something the panel shows.
@immutable
class RecurringSeries {
  const RecurringSeries({
    required this.id,
    required this.accountId,
    required this.label,
    required this.categoryId,
    required this.cadence,
    required this.medianIntervalDays,
    required this.expectedAmountMinor,
    required this.currency,
    required this.firstSeenDate,
    required this.lastSeenDate,
    required this.nextExpectedDate,
    required this.occurrenceCount,
    required this.status,
    required this.isManual,
    required this.priceChangeMinor,
    required this.priceChangedAt,
  });

  final String id;
  final String accountId;
  final String label;
  final String? categoryId;
  final Cadence cadence;
  final int medianIntervalDays;

  /// Signed integer minor units, so negative — a subscription is an outflow
  /// (`PROJECT.md` §8).
  final int expectedAmountMinor;

  final String currency;
  final DateTime firstSeenDate;
  final DateTime lastSeenDate;
  final DateTime nextExpectedDate;
  final int occurrenceCount;
  final SeriesStatus status;

  /// True for a series the user declared. Detection never writes to one.
  final bool isManual;

  /// Signed step in [expectedAmountMinor]; a price *rise* on an outflow is
  /// negative.
  final int? priceChangeMinor;

  final DateTime? priceChangedAt;

  /// What this series cost before the recorded price change, or `null` when
  /// there was none.
  int? get previousAmountMinor =>
      priceChangeMinor == null ? null : expectedAmountMinor - priceChangeMinor!;

  /// The price change carried out over a year — « soit +24,00 € par an ».
  ///
  /// Signed like the step it comes from, and `null` for a cadence with no
  /// period. This is the figure that turns « 2,00 € de plus » into something a
  /// user can weigh, which is why the detail screen states it rather than
  /// leaving the multiplication to them.
  int? get annualPriceImpactMinor {
    final change = priceChangeMinor;
    final perYear = cadence.occurrencesPerYear;
    if (change == null || perYear == null) return null;
    return change * perYear;
  }

  /// The transitions the lifecycle allows out of the current status.
  List<SeriesStatus> get allowedTransitions =>
      legalSeriesTransitions[status] ?? const [];
}

/// One charge a series was deduced from, and the transaction it is.
///
/// Deliberately narrower than the full `Transaction` the endpoint embeds: the
/// history table draws a date, an amount, and a change pill, and a second copy
/// of the transactions feature's twenty-field mapping would drift from the
/// first without ever being read.
@immutable
class SeriesOccurrence {
  const SeriesOccurrence({
    required this.id,
    required this.transactionId,
    required this.bookedDate,
    required this.amountMinor,
    required this.currency,
  });

  final String id;
  final String transactionId;
  final DateTime bookedDate;

  /// Signed minor units — a real ledger entry, so the detail table colors it.
  final int amountMinor;
  final String currency;
}

/// A series with the occurrence history it was built from, newest first.
@immutable
class SeriesDetail {
  const SeriesDetail({required this.series, required this.occurrences});

  final RecurringSeries series;
  final List<SeriesOccurrence> occurrences;
}

/// An account, as much of one as this panel needs: the row a series belongs to,
/// and the options the creation form offers.
///
/// Not the accounts feature's `Account` — that model carries balances and an
/// archive flag this panel has no use for, and a feature owns the wire shapes
/// it reads (see the architecture skill).
@immutable
class SeriesAccount {
  const SeriesAccount({
    required this.id,
    required this.name,
    required this.institution,
    required this.currency,
  });

  final String id;
  final String name;
  final String institution;
  final String currency;

  /// « BNP — Compte courant », the form the panel prints everywhere.
  String get displayName => '$institution — $name';
}
