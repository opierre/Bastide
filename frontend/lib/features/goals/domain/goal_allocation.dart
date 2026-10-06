import 'package:flutter/foundation.dart';

/// One line of a goal's ledger.
///
/// The ledger is append-only apart from deletion: there is no PATCH, because a
/// real correction is an offsetting line rather than a rewritten one. Taking
/// money back out of an envelope is a *negative* allocation, not a second kind
/// of record — which is why the modal has one signed amount field and the
/// history is one list.
@immutable
class GoalAllocation {
  const GoalAllocation({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.allocatedOn,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String goalId;

  /// Signed minor units: positive puts money aside, negative takes it back.
  final int amountMinor;

  final DateTime allocatedOn;
  final String? note;
  final DateTime createdAt;
}
