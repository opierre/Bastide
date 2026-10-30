import 'package:flutter/foundation.dart';

/// A deferred card's settlement rule as the API reports it: the rule's pattern
/// when the card has one, and the pattern proposed for it either way.
///
/// The rule files the card's monthly debit — on the account the card is paid
/// from — as a transfer, so that debit stops counting as spending on top of the
/// purchases the card already recorded one by one.
@immutable
class SettlementRuleState {
  const SettlementRuleState({this.ruleId, this.pattern, this.suggestedPattern});

  /// `null` while the card has no rule.
  final String? ruleId;

  /// The saved rule's pattern, matched against the cleaned label.
  final String? pattern;

  /// The label fragment naming the card that recurs month after month on the
  /// account paying it (`DEPENSES CARTE X4821`). `null` when the card's number
  /// is unknown.
  final String? suggestedPattern;

  bool get hasRule => ruleId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettlementRuleState &&
          other.ruleId == ruleId &&
          other.pattern == pattern &&
          other.suggestedPattern == suggestedPattern);

  @override
  int get hashCode => Object.hash(ruleId, pattern, suggestedPattern);
}
