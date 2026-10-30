import 'package:flutter/foundation.dart';

/// A deferred card's settlement rule as the API reports it: the rule's pattern
/// and start date when the card has one, and what is proposed for them either
/// way.
///
/// The rule files the card's monthly debit — on the account the card is paid
/// from — as a transfer, so that debit stops counting as spending on top of the
/// purchases the card already recorded one by one.
@immutable
class SettlementRuleState {
  const SettlementRuleState({
    this.ruleId,
    this.pattern,
    this.appliesFrom,
    this.suggestedPattern,
    this.suggestedAppliesFrom,
  });

  /// `null` while the card has no rule.
  final String? ruleId;

  /// The saved rule's pattern, matched against the cleaned label.
  final String? pattern;

  /// The saved rule files no debit booked before this day: those pay purchases
  /// from before the card's imported history, and stay spending.
  final DateTime? appliesFrom;

  /// The label fragment naming the card that recurs month after month on the
  /// account paying it (`DEPENSES CARTE X4821`). `null` when the card's number
  /// is unknown.
  final String? suggestedPattern;

  /// The first debit whose whole cycle the card's own statements cover.
  /// `null` while the card has no transaction.
  final DateTime? suggestedAppliesFrom;

  bool get hasRule => ruleId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettlementRuleState &&
          other.ruleId == ruleId &&
          other.pattern == pattern &&
          other.appliesFrom == appliesFrom &&
          other.suggestedPattern == suggestedPattern &&
          other.suggestedAppliesFrom == suggestedAppliesFrom);

  @override
  int get hashCode => Object.hash(
    ruleId,
    pattern,
    appliesFrom,
    suggestedPattern,
    suggestedAppliesFrom,
  );
}
