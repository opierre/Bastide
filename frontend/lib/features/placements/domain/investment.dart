import 'package:flutter/foundation.dart';

/// The envelope catalogue (`docs/design/17-placements.md` §Concept). Mirrors
/// the backend's `Envelope` literal; each one is labelled from ARB.
enum Envelope {
  pea('pea'),
  peaPme('pea_pme'),
  lifeInsurance('life_insurance'),
  per('per'),
  pee('pee'),
  securitiesAccount('securities_account'),
  other('other');

  const Envelope(this.wireValue);

  final String wireValue;

  /// The envelope named [value]; [other] for one this build doesn't know
  /// yet, so a newer backend's placement still lists.
  static Envelope fromWire(String value) => values.firstWhere(
    (envelope) => envelope.wireValue == value,
    orElse: () => other,
  );
}

/// A placement as `GET /investments` returns it: what the user declared, and
/// every figure derived from it server-side.
///
/// Nothing here is computed by the client. Net payments, the gain, its share,
/// the age and the milestone all come from the API, which recomputes them per
/// request and never stores them (`17-placements.md` §Concept).
@immutable
class Investment {
  const Investment({
    required this.id,
    required this.name,
    required this.institution,
    required this.envelope,
    required this.openedOn,
    required this.closedOn,
    required this.currency,
    required this.paidInMinor,
    required this.withdrawnMinor,
    required this.netPaymentsMinor,
    required this.lastValueMinor,
    required this.lastValuedOn,
    required this.unrealisedGainMinor,
    required this.gainBps,
    required this.valueStale,
    required this.ageMonths,
    required this.paymentCeilingMinor,
    required this.milestoneYears,
    required this.milestoneOn,
    required this.milestoneReached,
    required this.movementCount,
    required this.linkedMovementCount,
  });

  final String id;
  final String name;
  final String institution;
  final Envelope envelope;
  final DateTime openedOn;
  final DateTime? closedOn;
  final String currency;

  /// Sum of the payments in, ≥ 0.
  final int paidInMinor;

  /// Sum of the withdrawals, ≤ 0.
  final int withdrawnMinor;

  /// Paid in plus withdrawn: what the user put in, net.
  final int netPaymentsMinor;

  /// The latest declared value; `null` before the first declaration.
  final int? lastValueMinor;
  final DateTime? lastValuedOn;

  /// Last value − net payments, signed; `null` without a declared value and
  /// for a closed placement.
  final int? unrealisedGainMinor;

  /// The gain as a share of net payments, in bps; `null` when meaningless.
  final int? gainBps;

  /// The latest declared value is older than four months (open only).
  final bool valueStale;

  /// Whole months since opening, up to today or the closing date.
  final int ageMonths;

  /// The envelope's payment ceiling; `null` without one.
  final int? paymentCeilingMinor;

  /// The envelope's age milestone in years; `null` without one.
  final int? milestoneYears;
  final DateTime? milestoneOn;
  final bool milestoneReached;

  final int movementCount;

  /// Movements reconciled with an imported transaction.
  final int linkedMovementCount;

  bool get isClosed => closedOn != null;
  bool get hasValue => lastValueMinor != null;

  /// The net payments have reached the envelope's ceiling.
  bool get ceilingReached =>
      paymentCeilingMinor != null && netPaymentsMinor >= paymentCeilingMinor!;
}

/// A payment in (positive) or a withdrawal (negative).
@immutable
class InvestmentMovement {
  const InvestmentMovement({
    required this.id,
    required this.investmentId,
    required this.occurredOn,
    required this.amountMinor,
    required this.note,
    required this.transactionId,
  });

  final String id;
  final String investmentId;
  final DateTime occurredOn;

  /// Signed, never zero.
  final int amountMinor;
  final String? note;

  /// The imported transaction it is reconciled with, for reference only.
  final String? transactionId;

  bool get isWithdrawal => amountMinor < 0;
}

/// A value copied from a statement.
@immutable
class InvestmentValuation {
  const InvestmentValuation({
    required this.id,
    required this.investmentId,
    required this.valuedOn,
    required this.valueMinor,
    required this.note,
  });

  final String id;
  final String investmentId;
  final DateTime valuedOn;

  /// ≥ 0: a value, not a movement.
  final int valueMinor;
  final String? note;
}

/// One line of « Mouvements »: a movement or a declared value.
@immutable
sealed class HistoryEntry {
  const HistoryEntry();

  DateTime get date;
  String get id;
}

final class MovementEntry extends HistoryEntry {
  const MovementEntry(this.movement);

  final InvestmentMovement movement;

  @override
  DateTime get date => movement.occurredOn;

  @override
  String get id => movement.id;
}

final class ValuationEntry extends HistoryEntry {
  const ValuationEntry(this.valuation);

  final InvestmentValuation valuation;

  @override
  DateTime get date => valuation.valuedOn;

  @override
  String get id => valuation.id;
}

/// One placement with its whole history (`GET /investments/{id}`).
@immutable
class InvestmentDetail {
  const InvestmentDetail({
    required this.investment,
    required this.movements,
    required this.valuations,
  });

  final Investment investment;

  /// Newest first, as the API sends them.
  final List<InvestmentMovement> movements;
  final List<InvestmentValuation> valuations;

  /// Payments, withdrawals and declared values in one list, newest first
  /// (`17-placements.md` §Inspector 7). On one day, the value is listed
  /// above the movements: a statement reads the day's balance after them.
  List<HistoryEntry> get history {
    final entries = <HistoryEntry>[
      for (final valuation in valuations) ValuationEntry(valuation),
      for (final movement in movements) MovementEntry(movement),
    ];
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, entry) in indexed) entry];
  }
}

/// `GET /investments/summary`: the summary line over the open placements.
@immutable
class InvestmentSummary {
  const InvestmentSummary({
    required this.openCount,
    required this.closedCount,
    required this.declaredValueMinor,
    required this.netPaymentsMinor,
    required this.unrealisedGainMinor,
    required this.gainBps,
    required this.valuedCount,
    required this.staleCount,
    required this.lastValuedOn,
    required this.currency,
  });

  final int openCount;
  final int closedCount;
  final int declaredValueMinor;
  final int netPaymentsMinor;
  final int unrealisedGainMinor;
  final int? gainBps;
  final int valuedCount;
  final int staleCount;
  final DateTime? lastValuedOn;
  final String currency;
}

/// An imported transaction that may have funded a movement: same amount,
/// opposite sign, near the movement's date.
@immutable
class LinkCandidate {
  const LinkCandidate({
    required this.transactionId,
    required this.accountName,
    required this.bookedDate,
    required this.amountMinor,
    required this.currency,
    required this.description,
  });

  final String transactionId;
  final String accountName;
  final DateTime bookedDate;
  final int amountMinor;
  final String currency;
  final String description;
}
