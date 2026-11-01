import 'package:flutter/foundation.dart';

import 'recurring_series.dart';

/// How sure the server is that a preview's transactions make a series. Mirrors
/// `PreviewConfidence` in `backend/app/features/recurring/schemas.py`.
enum PreviewConfidence {
  high,
  medium,

  /// No rhythm was found: saving still works, as an `irregular` series.
  low;

  static PreviewConfidence fromWire(String value) =>
      PreviewConfidence.values.firstWhere((level) => level.name == value);
}

/// Why a preview graded as it did. Mirrors `PreviewReason` in the backend's
/// schemas; the server sends keys, the client words them.
enum PreviewReason {
  occurrences('occurrences'),
  cadenceWeekly('cadence_weekly'),
  cadenceMonthly('cadence_monthly'),
  cadenceQuarterly('cadence_quarterly'),
  cadenceYearly('cadence_yearly'),
  amountStable('amount_stable'),
  amountChanged('amount_changed'),
  amountOutsideTolerance('amount_outside_tolerance'),
  gapOutsideTolerance('gap_outside_tolerance'),
  tooFewOccurrences('too_few_occurrences'),
  noRhythm('no_rhythm');

  const PreviewReason(this.wireValue);

  final String wireValue;

  /// `null` for a key this build does not know yet, so a newer server never
  /// breaks the dialog — the reason is simply not listed.
  static PreviewReason? fromWire(String value) =>
      PreviewReason.values.where((r) => r.wireValue == value).firstOrNull;
}

/// One transaction a preview would group, narrowed to what the checklist shows.
@immutable
class PreviewTransaction {
  const PreviewTransaction({
    required this.id,
    required this.bookedDate,
    required this.amountMinor,
    required this.currency,
    required this.label,
  });

  final String id;
  final DateTime bookedDate;

  /// Signed minor units — negative, every preview transaction is an outflow.
  final int amountMinor;
  final String currency;

  /// The merchant when the import found one, the cleaned bank label otherwise.
  final String label;
}

/// The series a transaction and its matches would make, before anything is
/// saved — `POST /recurring/preview`.
@immutable
class SeriesPreview {
  const SeriesPreview({
    required this.confidence,
    required this.reasons,
    required this.cadence,
    required this.label,
    required this.expectedAmountMinor,
    required this.currency,
    required this.accountId,
    required this.transactions,
  });

  final PreviewConfidence confidence;
  final List<PreviewReason> reasons;

  /// [Cadence.irregular] when [confidence] is low.
  final Cadence cadence;
  final String label;

  /// Signed, so negative.
  final int expectedAmountMinor;
  final String currency;
  final String accountId;

  /// Oldest first, the transaction the preview started from included.
  final List<PreviewTransaction> transactions;
}

/// What a preview request answers: a proposal, or the series the transaction
/// already belongs to.
@immutable
sealed class PreviewOutcome {
  const PreviewOutcome();
}

/// The transaction is already part of [series]; the client opens it instead of
/// proposing a second one.
final class AlreadyInSeries extends PreviewOutcome {
  const AlreadyInSeries(this.series);

  final RecurringSeries series;
}

/// A new series is proposed.
final class Proposal extends PreviewOutcome {
  const Proposal(this.preview);

  final SeriesPreview preview;
}
