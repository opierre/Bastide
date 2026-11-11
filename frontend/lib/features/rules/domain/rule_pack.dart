import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'rule.dart';

/// The one pack format this build reads. Mirrors `SUPPORTED_FORMAT_VERSION` in
/// `backend/app/features/rules/packs/schema.py`; the normative contract is
/// `docs/schemas/rule-pack.v1.schema.json`.
const rulePackFormatVersion = 1;

/// A pack entry's logo: embedded (`{"data": <base64>}`) or linked
/// (`{"url", "license", "source"}`, always on Wikimedia).
///
/// Kept as the wire object rather than parsed into fields: the client only
/// needs to *show* a logo and to send the pack back to the backend unchanged,
/// and the backend is the one that validates it. Re-serializing a field-by-field
/// copy would drop whatever a later format adds.
// Not @immutable only because of the lazily decoded [embeddedBytes]: decoding
// is memoized so a rebuilt preview row hands `Image.memory` the same bytes.
class RulePackLogo {
  RulePackLogo(Map<String, dynamic> json) : _json = Map.unmodifiable(json);

  final Map<String, dynamic> _json;

  /// The base64 picture, or `null` for a linked logo.
  String? get embeddedData => switch (_json['data']) {
    final String data => data,
    _ => null,
  };

  /// Whether the logo is a link the import downloads only when asked to.
  bool get isLinked => _json.containsKey('url');

  /// The embedded picture's bytes, or `null` when the logo is linked or its
  /// base64 doesn't decode — the preview then falls back to the monogram.
  late final Uint8List? embeddedBytes = _decode();

  /// The embedded picture's decoded size, without decoding it.
  int get embeddedSize {
    final data = embeddedData;
    if (data == null) return 0;
    final padding = data.length - data.replaceAll(RegExp(r'=+$'), '').length;
    return data.length ~/ 4 * 3 - padding;
  }

  Uint8List? _decode() {
    final data = embeddedData;
    if (data == null) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => Map.of(_json);
}

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
    this.logo,
  });

  factory RulePackEntry.fromJson(Map<String, dynamic> json) => RulePackEntry(
    field: json['field'] as String,
    type: json['type'] as String,
    pattern: json['pattern'] as String,
    categoryKey: json['category_key'] as String,
    enabled: json['enabled'] as bool? ?? true,
    comment: json['comment'] as String?,
    logo: switch (json['logo']) {
      final Map<String, dynamic> logo => RulePackLogo(logo),
      _ => null,
    },
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
  final RulePackLogo? logo;

  /// The entry as the wire carries it. [elideLogo], when given, replaces an
  /// embedded logo's base64 with what it returns for the picture's size: a
  /// logo is tens of kilobytes of base64 the user can't read, so the review
  /// sheet shows a stand-in while the saved file keeps the picture.
  Map<String, dynamic> toJson({String Function(int bytes)? elideLogo}) => {
    'field': field,
    'type': type,
    'pattern': pattern,
    'category_key': categoryKey,
    'enabled': enabled,
    if (comment != null) 'comment': comment,
    if (logo case final logo?)
      'logo': elideLogo != null && logo.embeddedData != null
          ? {'data': elideLogo(logo.embeddedSize)}
          : logo.toJson(),
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

  Map<String, dynamic> toJson({String Function(int bytes)? elideLogo}) => {
    'format_version': formatVersion,
    'name': name,
    if (description != null) 'description': description,
    if (locale != null) 'locale': locale,
    if (sourceUrl != null) 'source_url': sourceUrl,
    'rules': [for (final rule in rules) rule.toJson(elideLogo: elideLogo)],
  };

  /// The file the user saves, pretty-printed so a pack stays something a human
  /// can read and edit — that is the whole point of a portable format.
  ///
  /// [elideLogo] is for display only — see [RulePackEntry.toJson].
  String toPrettyJson({String Function(int bytes)? elideLogo}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(elideLogo: elideLogo));
}

/// A pack bundled with the app, as listed by `GET /rules/packs/builtin`.
@immutable
class BuiltinPack {
  const BuiltinPack({
    required this.id,
    required this.name,
    required this.locale,
    required this.ruleCount,
    required this.imported,
  });

  factory BuiltinPack.fromJson(Map<String, dynamic> json) => BuiltinPack(
    id: json['id'] as String,
    name: json['name'] as String,
    locale: json['locale'] as String?,
    ruleCount: json['rule_count'] as int,
    imported: json['imported'] as bool,
  );

  final String id;
  final String name;
  final String? locale;
  final int ruleCount;

  /// The user has already imported this pack: the app no longer offers it.
  final bool imported;
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
    this.logoCount = 0,
    this.logoDownloadCount = 0,
  });

  factory RulePackPreview.fromJson(Map<String, dynamic> json) =>
      RulePackPreview(
        name: json['name'] as String,
        total: json['total'] as int,
        newCount: json['new_count'] as int,
        duplicateCount: json['duplicate_count'] as int,
        unresolved: (json['unresolved'] as List<dynamic>).cast<String>(),
        wouldMatchCount: json['would_match_count'] as int,
        samples: (json['samples'] as List<dynamic>)
            .map((entry) => RuleSample.fromJson(entry as Map<String, dynamic>))
            .toList(),
        logoCount: json['logo_count'] as int? ?? 0,
        logoDownloadCount: json['logo_download_count'] as int? ?? 0,
      );

  final String name;
  final int total;
  final int newCount;
  final int duplicateCount;

  /// Category keys this install has no category for — those rules are skipped.
  final List<String> unresolved;
  final int wouldMatchCount;
  final List<RuleSample> samples;

  /// Logos the import would attach: on new rules, and on matching rules that
  /// have none yet.
  final int logoCount;

  /// How many of [logoCount] are links, attached only when the import is asked
  /// to download them. Previewing never downloads anything.
  final int logoDownloadCount;

  /// Whether the pack links logos, so the sheet offers to download them.
  bool get linksLogos => logoDownloadCount > 0;

  /// Whether importing would change anything: new rules, or logos for rules
  /// the user already has. A pack that only brings logos is still worth
  /// importing.
  bool get hasAnythingToImport => newCount > 0 || logoCount > 0;
}

/// Why a pack logo was not attached. Its rule was imported regardless.
enum RulePackLogoFailureReason {
  invalidImage('invalid_image'),
  tooLarge('too_large'),
  downloadFailed('download_failed');

  const RulePackLogoFailureReason(this.wire);

  final String wire;

  static RulePackLogoFailureReason fromWire(String value) => values.firstWhere(
    (reason) => reason.wire == value,
    orElse: () => RulePackLogoFailureReason.invalidImage,
  );
}

/// A pack logo the import could not attach.
@immutable
class RulePackLogoFailure {
  const RulePackLogoFailure({
    required this.index,
    required this.pattern,
    required this.reason,
  });

  factory RulePackLogoFailure.fromJson(Map<String, dynamic> json) =>
      RulePackLogoFailure(
        index: json['index'] as int,
        pattern: json['pattern'] as String,
        reason: RulePackLogoFailureReason.fromWire(json['reason'] as String),
      );

  /// The entry's position in the pack's rules, from 0.
  final int index;
  final String pattern;
  final RulePackLogoFailureReason reason;
}

/// What an import did.
@immutable
class RulePackImportResult {
  const RulePackImportResult({
    required this.createdCount,
    required this.skippedCount,
    required this.unresolved,
    required this.recategorizedCount,
    this.logoCount = 0,
    this.logoSkippedCount = 0,
    this.logoFailures = const [],
  });

  factory RulePackImportResult.fromJson(Map<String, dynamic> json) =>
      RulePackImportResult(
        createdCount: json['created_count'] as int,
        skippedCount: json['skipped_count'] as int,
        unresolved: (json['unresolved'] as List<dynamic>).cast<String>(),
        recategorizedCount: json['recategorized_count'] as int,
        logoCount: json['logo_count'] as int? ?? 0,
        logoSkippedCount: json['logo_skipped_count'] as int? ?? 0,
        logoFailures: (json['logo_failures'] as List<dynamic>? ?? const [])
            .map(
              (entry) =>
                  RulePackLogoFailure.fromJson(entry as Map<String, dynamic>),
            )
            .toList(),
      );

  final int createdCount;
  final int skippedCount;
  final List<String> unresolved;
  final int recategorizedCount;

  /// Logos stored: on new rules, and on matching rules that had none.
  final int logoCount;

  /// Linked logos left out because the import wasn't asked to download them.
  final int logoSkippedCount;

  /// Logos that could not be attached. A failing logo never fails the import.
  final List<RulePackLogoFailure> logoFailures;
}

/// Where a background pack import stands — `RulePackImportRunStatus`.
enum RulePackImportRunStatus {
  running,
  finished,
  failed;

  /// An unknown value reads as [running]: the snapshot is re-read until it
  /// says something this build understands, rather than ending on a guess.
  static RulePackImportRunStatus fromWire(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => RulePackImportRunStatus.running,
  );

  bool get isTerminal => this != RulePackImportRunStatus.running;
}

/// A pack import running in the background: its logo downloads, then what it
/// did (`GET /rules/packs/import-runs/{id}`).
@immutable
class RulePackImportRun {
  const RulePackImportRun({
    required this.id,
    required this.status,
    this.logoDone = 0,
    this.logoTotal = 0,
    this.result,
    this.errorMessage,
  });

  factory RulePackImportRun.fromJson(Map<String, dynamic> json) =>
      RulePackImportRun(
        id: json['id'] as String,
        status: RulePackImportRunStatus.fromWire(json['status'] as String),
        logoDone: json['logo_done'] as int? ?? 0,
        logoTotal: json['logo_total'] as int? ?? 0,
        result: switch (json['result']) {
          final Map<String, dynamic> result => RulePackImportResult.fromJson(
            result,
          ),
          _ => null,
        },
        errorMessage: json['error_message'] as String?,
      );

  final String id;
  final RulePackImportRunStatus status;

  /// Distinct logo URLs settled so far, downloaded or not, out of [logoTotal].
  final int logoDone;

  /// Distinct logo URLs to download; 0 until the rules are in, and when the
  /// import downloads none.
  final int logoTotal;

  /// What the import did, once [RulePackImportRunStatus.finished].
  final RulePackImportResult? result;

  /// Set when failed. Not shown as is: it is English, the app says it in the
  /// user's language.
  final String? errorMessage;

  /// Share of the logo downloads settled, from 0 to 1.
  double get logoProgress => logoTotal == 0 ? 0 : logoDone / logoTotal;

  RulePackImportRun withProgress({
    RulePackImportRunStatus? status,
    required int logoDone,
    required int logoTotal,
    String? errorMessage,
  }) => RulePackImportRun(
    id: id,
    status: status ?? this.status,
    logoDone: logoDone,
    logoTotal: logoTotal,
    result: result,
    errorMessage: errorMessage ?? this.errorMessage,
  );
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
  const RulePackExport({
    required this.pack,
    required this.omitted,
    this.logoCount = 0,
    this.logoBytes = 0,
    this.logosTooLarge = false,
  });

  factory RulePackExport.fromJson(Map<String, dynamic> json) => RulePackExport(
    pack: RulePack.fromJson(json['pack'] as Map<String, dynamic>),
    omitted: (json['omitted'] as List<dynamic>)
        .map((entry) => OmittedRule.fromJson(entry as Map<String, dynamic>))
        .toList(),
    logoCount: json['logo_count'] as int? ?? 0,
    logoBytes: json['logo_bytes'] as int? ?? 0,
    logosTooLarge: json['logos_too_large'] as bool? ?? false,
  );

  final RulePack pack;
  final List<OmittedRule> omitted;

  /// Logos embedded in [pack], when the export was asked for them.
  final int logoCount;

  /// The decoded bytes those logos add up to, or would have when
  /// [logosTooLarge].
  final int logoBytes;

  /// The logos would take the pack over the size an import accepts, so [pack]
  /// carries none of them — its rules are all there regardless.
  final bool logosTooLarge;
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
