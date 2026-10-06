import 'package:flutter/foundation.dart';

/// Which part of a transaction a rule looks at. Wire values are the backend's
/// `MatchField` literals (`backend/app/features/rules/schemas.py`).
enum RuleMatchField {
  descriptionClean('description_clean'),
  merchant('merchant'),
  amount('amount');

  const RuleMatchField(this.wire);

  final String wire;

  static RuleMatchField fromWire(String value) => values.firstWhere(
    (field) => field.wire == value,
    orElse: () => RuleMatchField.descriptionClean,
  );
}

/// How the rule compares its pattern against that field.
///
/// `range` reads `amount_minor` rather than a text field whatever `match_field`
/// says — see `engine.py` — so the editor pairs it with the amount field.
enum RuleMatchType {
  contains('contains'),
  equals('equals'),
  regex('regex'),
  range('range');

  const RuleMatchType(this.wire);

  final String wire;

  static RuleMatchType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => RuleMatchType.contains,
  );
}

/// A categorization rule. Evaluated ascending by [priority], first match wins,
/// and never over a transaction the user categorized by hand.
@immutable
class Rule {
  const Rule({
    required this.id,
    required this.priority,
    required this.matchField,
    required this.matchType,
    required this.pattern,
    required this.categoryId,
    required this.enabled,
    required this.createdAt,
  });

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
    id: json['id'] as String,
    priority: json['priority'] as int,
    matchField: RuleMatchField.fromWire(json['match_field'] as String),
    matchType: RuleMatchType.fromWire(json['match_type'] as String),
    pattern: json['pattern'] as String,
    categoryId: json['category_id'] as String,
    enabled: json['enabled'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final int priority;
  final RuleMatchField matchField;
  final RuleMatchType matchType;
  final String pattern;
  final String categoryId;
  final bool enabled;
  final DateTime createdAt;

  Rule copyWith({int? priority, bool? enabled}) => Rule(
    id: id,
    priority: priority ?? this.priority,
    matchField: matchField,
    matchType: matchType,
    pattern: pattern,
    categoryId: categoryId,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rule &&
          other.id == id &&
          other.priority == priority &&
          other.matchField == matchField &&
          other.matchType == matchType &&
          other.pattern == pattern &&
          other.categoryId == categoryId &&
          other.enabled == enabled &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    priority,
    matchField,
    matchType,
    pattern,
    categoryId,
    enabled,
    createdAt,
  );
}

/// One transaction a preview matched, reduced to what the banner names it by.
///
/// A projection of the API's `TransactionRead`, not a second transaction model:
/// the preview banner quotes a label and a date (« dont "CB CARREFOUR PARIS 15"
/// du 14/05/2026 »), and parsing the other fifteen fields to throw them away
/// would tie this feature to a shape only the transactions panel renders.
@immutable
class RuleSample {
  const RuleSample({
    required this.id,
    required this.descriptionClean,
    required this.bookedDate,
  });

  factory RuleSample.fromJson(Map<String, dynamic> json) => RuleSample(
    id: json['id'] as String,
    descriptionClean: json['description_clean'] as String,
    bookedDate: DateTime.parse(json['booked_date'] as String),
  );

  final String id;
  final String descriptionClean;
  final DateTime bookedDate;
}

/// What an unsaved rule condition would match today.
@immutable
class RulePreview {
  const RulePreview({required this.matchCount, required this.samples});

  final int matchCount;
  final List<RuleSample> samples;
}

/// The backend's pre-fill for a rule derived from one transaction
/// (`GET /rules/suggestion`).
///
/// A default, not a constraint — the form may override every field. Derived
/// server-side because knowing which parts of a French bank label are noise is
/// the same knowledge the import pipeline applies when it cleans a description;
/// a second copy of those heuristics in Dart would drift and
/// suggest rules that don't match the row they came from.
@immutable
class RuleSuggestion {
  const RuleSuggestion({
    required this.matchField,
    required this.matchType,
    required this.pattern,
  });

  factory RuleSuggestion.fromJson(Map<String, dynamic> json) => RuleSuggestion(
    matchField: RuleMatchField.fromWire(json['match_field'] as String),
    matchType: RuleMatchType.fromWire(json['match_type'] as String),
    pattern: json['pattern'] as String,
  );

  final RuleMatchField matchField;
  final RuleMatchType matchType;
  final String pattern;
}

/// What `POST /rules/from-transaction` reports back: the rule, and how many
/// *other* rows it moved.
@immutable
class RuleFromTransactionResult {
  const RuleFromTransactionResult({
    required this.rule,
    required this.recategorizedCount,
  });

  final Rule rule;
  final int recategorizedCount;
}
