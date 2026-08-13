import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'rule.dart';

/// The one pack format this build reads. Mirrors `SUPPORTED_FORMAT_VERSION` in
/// `backend/app/features/rules/packs/schema.py`; the normative contract is
/// `docs/schemas/rule-pack.v1.schema.json`.
const rulePackFormatVersion = 1;

/// One rule in a pack: a condition plus the *system* category key it assigns.
///
/// Categories travel as keys (`category.food.groceries`) rather than ids —
/// ids are per-install, so an id in a shared file would bind nothing or, worse,
/// something else.
@immutable
class RulePackEntry {
  const RulePackEntry({
    required this.field,
    required this.type,
    required this.pattern,
    required this.categoryKey,
    this.enabled = true,
    this.comment,
  });

  factory RulePackEntry.fromJson(Map<String, dynamic> json) => RulePackEntry(
    field: json['field'] as String,
    type: json['type'] as String,
    pattern: json['pattern'] as String,
    categoryKey: json['category_key'] as String,
    enabled: json['enabled'] as bool? ?? true,
    comment: json['comment'] as String?,
  );

  /// Kept as wire strings rather than [RuleMatchField] / [RuleMatchType]: a
  /// pack arriving from a stranger may carry values this build doesn't know,
  /// and the import sheet has to be able to *show* the user what it refused.
  final String field;
  final String type;
  final String pattern;
  final String categoryKey;
  final bool enabled;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'field': field,
    'type': type,
    'pattern': pattern,
    'category_key': categoryKey,
    'enabled': enabled,
    if (comment != null) 'comment': comment,
  };
}

/// A portable set of rules.
@immutable
class RulePack {
  const RulePack({
    required this.formatVersion,
    required this.name,
    required this.rules,
    this.description,
    this.locale,
    this.sourceUrl,
  });

  factory RulePack.fromJson(Map<String, dynamic> json) => RulePack(
    formatVersion: json['format_version'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    locale: json['locale'] as String?,
    sourceUrl: json['source_url'] as String?,
    rules: (json['rules'] as List<dynamic>)
        .map((entry) => RulePackEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  final int formatVersion;
  final String name;
  final String? description;
  final String? locale;
  final String? sourceUrl;
  final List<RulePackEntry> rules;

  Map<String, dynamic> toJson() => {
    'format_version': formatVersion,
    'name': name,
    if (description != null) 'description': description,
    if (locale != null) 'locale': locale,
    if (sourceUrl != null) 'source_url': sourceUrl,
    'rules': [for (final rule in rules) rule.toJson()],
  };

  /// The file the user saves, pretty-printed so a pack stays something a human
  /// can read and edit — that is the whole point of a portable format.
  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// A pack bundled with the app, as listed by `GET /rules/packs/builtin`.
@immutable
class BuiltinPack {
  const BuiltinPack({
    required this.id,
    required this.name,
    required this.locale,
    required this.ruleCount,
  });

  factory BuiltinPack.fromJson(Map<String, dynamic> json) => BuiltinPack(
    id: json['id'] as String,
    name: json['name'] as String,
    locale: json['locale'] as String?,
    ruleCount: json['rule_count'] as int,
  );

  final String id;
  final String name;
  final String? locale;
  final int ruleCount;
}

/// What an import *would* do. Shown before anything is written — the count is
/// the whole reason a user can judge a stranger's pack.
@immutable
class RulePackPreview {
  const RulePackPreview({
    required this.name,
    required this.total,
    required this.newCount,
    required this.duplicateCount,
    required this.unresolved,
    required this.wouldMatchCount,
    required this.samples,
  });

  factory RulePackPreview.fromJson(Map<String, dynamic> json) => RulePackPreview(
    name: json['name'] as String,
    total: json['total'] as int,
    newCount: json['new_count'] as int,
    duplicateCount: json['duplicate_count'] as int,
    unresolved: (json['unresolved'] as List<dynamic>).cast<String>(),
    wouldMatchCount: json['would_match_count'] as int,
    samples: (json['samples'] as List<dynamic>)
        .map((entry) => RuleSample.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  final String name;
  final int total;
  final int newCount;
  final int duplicateCount;

  /// Category keys this install has no category for — those rules are skipped.
  final List<String> unresolved;
  final int wouldMatchCount;
  final List<RuleSample> samples;
}

/// What an import did.
@immutable
class RulePackImportResult {
  const RulePackImportResult({
    required this.createdCount,
    required this.skippedCount,
    required this.unresolved,
    required this.recategorizedCount,
  });

  factory RulePackImportResult.fromJson(Map<String, dynamic> json) =>
      RulePackImportResult(
        createdCount: json['created_count'] as int,
        skippedCount: json['skipped_count'] as int,
        unresolved: (json['unresolved'] as List<dynamic>).cast<String>(),
        recategorizedCount: json['recategorized_count'] as int,
      );

  final int createdCount;
  final int skippedCount;
  final List<String> unresolved;
  final int recategorizedCount;
}

/// Why a rule couldn't be carried into an export.
enum RuleOmissionReason {
  regex('regex'),
  userCategory('user_category');

  const RuleOmissionReason(this.wire);

  final String wire;

  static RuleOmissionReason fromWire(String value) => values.firstWhere(
    (reason) => reason.wire == value,
    orElse: () => RuleOmissionReason.userCategory,
  );
}

@immutable
class OmittedRule {
  const OmittedRule({
    required this.ruleId,
    required this.pattern,
    required this.reason,
  });

  factory OmittedRule.fromJson(Map<String, dynamic> json) => OmittedRule(
    ruleId: json['rule_id'] as String,
    pattern: json['pattern'] as String,
    reason: RuleOmissionReason.fromWire(json['reason'] as String),
  );

  final String ruleId;
  final String pattern;
  final RuleOmissionReason reason;
}

/// The export the user reviews before it becomes a file, plus what it left out.
@immutable
class RulePackExport {
  const RulePackExport({required this.pack, required this.omitted});

  factory RulePackExport.fromJson(Map<String, dynamic> json) => RulePackExport(
    pack: RulePack.fromJson(json['pack'] as Map<String, dynamic>),
    omitted: (json['omitted'] as List<dynamic>)
        .map((entry) => OmittedRule.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  final RulePack pack;
  final List<OmittedRule> omitted;
}

/// Why a chosen file is not a pack this build will take.
enum RulePackRefusal {
  /// Not JSON, or JSON that isn't a pack-shaped object.
  malformed,

  /// A `format_version` other than [rulePackFormatVersion]. Refused outright
  /// rather than parsed best-effort: a pack we half-understood would silently
  /// drop the rules it didn't.
  unsupportedVersion,

  /// The pack contains a `regex` rule. `engine.py` runs `re.search` unbounded
  /// against every transaction and Python's `re` cannot cap backtracking, so a
  /// pattern arriving in someone else's file is a denial of service against
  /// the importer's own machine in a way a hand-typed one is not.
  regexNotAllowed,
}

/// A refused file, carrying why.
class RulePackRejected implements Exception {
  const RulePackRejected(this.reason);

  final RulePackRefusal reason;

  @override
  String toString() => 'RulePackRejected($reason)';
}

/// Parses a chosen file into a pack, refusing it with a stated reason.
///
/// Done here as well as server-side because the backend's refusals arrive as
/// FastAPI's schema-validation 422, which carries no `{error:{code}}` envelope
/// and so reaches the client as a generic failure. Reading the two documented
/// refusal reasons off the file itself is what lets the sheet explain *why* a
/// file was turned away instead of reporting that something went wrong.
///
/// Throws [RulePackRejected].
RulePack parseRulePack(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    throw const RulePackRejected(RulePackRefusal.malformed);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const RulePackRejected(RulePackRefusal.malformed);
  }

  final version = decoded['format_version'];
  if (version is! int) throw const RulePackRejected(RulePackRefusal.malformed);
  if (version != rulePackFormatVersion) {
    throw const RulePackRejected(RulePackRefusal.unsupportedVersion);
  }

  final rules = decoded['rules'];
  if (decoded['name'] is! String || rules is! List) {
    throw const RulePackRejected(RulePackRefusal.malformed);
  }
  for (final entry in rules) {
    if (entry is! Map<String, dynamic>) {
      throw const RulePackRejected(RulePackRefusal.malformed);
    }
    if (entry['type'] == 'regex') {
      throw const RulePackRejected(RulePackRefusal.regexNotAllowed);
    }
  }

  try {
    return RulePack.fromJson(decoded);
  } catch (_) {
    throw const RulePackRejected(RulePackRefusal.malformed);
  }
}
