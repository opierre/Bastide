import 'package:flutter/foundation.dart';

/// What keeps a deferred card's purchases from counting exactly once — the
/// first missing step only.
enum CardSettlementIssueKind {
  /// The card doesn't say which account its monthly debit is drawn from.
  noSettlementAccount('no_settlement_account'),

  /// The card has no rule filing that debit as a transfer, so it counts as
  /// spending on top of the purchases.
  noRule('no_rule'),

  /// The card has purchases since its last settlement that the paying
  /// account, imported well past them, shows no debit for: the rule likely no
  /// longer matches how the bank words it.
  unsettled('unsettled');

  const CardSettlementIssueKind(this.wire);

  final String wire;

  static CardSettlementIssueKind fromWire(String value) =>
      values.firstWhere((kind) => kind.wire == value);
}

/// One card needing the user's attention (`GET /accounts/settlement-status`).
@immutable
class CardSettlementIssue {
  const CardSettlementIssue({
    required this.accountId,
    required this.kind,
    this.amountMinor,
    this.count,
    this.since,
  });

  final String accountId;
  final CardSettlementIssueKind kind;

  /// [CardSettlementIssueKind.unsettled] only: the purchases' total, signed
  /// (negative), how many, and the oldest one's date.
  final int? amountMinor;
  final int? count;
  final DateTime? since;
}
