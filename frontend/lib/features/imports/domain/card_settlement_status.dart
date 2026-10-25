import 'package:flutter/foundation.dart';

/// A deferred card's purchases that no settlement has claimed, though the debit
/// paying them is overdue — so they count as spending twice until that debit is
/// filed as a card settlement.
@immutable
class UnmatchedCardPurchases {
  const UnmatchedCardPurchases({
    required this.accountId,
    required this.amountMinor,
    required this.count,
    required this.since,
  });

  final String accountId;

  /// Their total, signed — so negative.
  final int amountMinor;
  final int count;

  /// The oldest of them.
  final DateTime since;
}

/// `GET /imports/card-settlements`: what the user still has to settle for
/// their deferred cards to count once.
@immutable
class CardSettlementStatus {
  const CardSettlementStatus({
    required this.proposedCount,
    required this.unmatched,
  });

  /// Settlements recognised by their label, waiting in the review queue.
  final int proposedCount;
  final List<UnmatchedCardPurchases> unmatched;
}
