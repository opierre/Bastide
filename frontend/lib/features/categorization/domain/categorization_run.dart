import 'package:flutter/foundation.dart';

/// Which rows a run reconsiders — the backend's `RunScope` literals
/// (`backend/app/features/categorization/schemas.py`).
enum RunScope {
  /// Only what nothing has categorized yet.
  pending,

  /// Also rows a previous run assigned, so a changed model or threshold can be
  /// applied to them. Never a `user` or `rule` row either way (PROJECT.md §7).
  all;

  String get wire => name;
}

/// What started the run.
enum RunTrigger {
  import,
  manual;

  static RunTrigger fromWire(String value) => values.firstWhere(
    (trigger) => trigger.name == value,
    orElse: () => RunTrigger.manual,
  );
}

/// A run's lifecycle. `pending`/`running` are the in-flight pair the poll
/// watches for; the other four are terminal.
enum RunStatus {
  pending,
  running,

  /// Every row was judged.
  success,

  /// Some rows failed; the rest were judged.
  partial,

  /// The run got nowhere at all.
  failed,
  cancelled;

  static RunStatus fromWire(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => RunStatus.pending,
  );

  bool get isInFlight => this == RunStatus.pending || this == RunStatus.running;

  bool get isTerminal => !isInFlight;
}

/// One stage-2 categorization run, polled for progress while it is in flight
/// (PROJECT.md §4/§7).
@immutable
class CategorizationRun {
  const CategorizationRun({
    required this.id,
    required this.accountId,
    required this.importBatchId,
    required this.trigger,
    required this.status,
    required this.modelTag,
    required this.totalCount,
    required this.processedCount,
    required this.assignedCount,
    required this.deferredCount,
    required this.failedCount,
    required this.errorMessage,
    required this.startedAt,
    required this.finishedAt,
    required this.createdAt,
  });

  factory CategorizationRun.fromJson(Map<String, dynamic> json) =>
      CategorizationRun(
        id: json['id'] as String,
        accountId: json['account_id'] as String?,
        importBatchId: json['import_batch_id'] as String?,
        trigger: RunTrigger.fromWire(json['trigger'] as String),
        status: RunStatus.fromWire(json['status'] as String),
        modelTag: json['model_tag'] as String?,
        totalCount: json['total_count'] as int,
        processedCount: json['processed_count'] as int,
        assignedCount: json['assigned_count'] as int,
        deferredCount: json['deferred_count'] as int,
        failedCount: json['failed_count'] as int,
        errorMessage: json['error_message'] as String?,
        startedAt: _parseDate(json['started_at']),
        finishedAt: _parseDate(json['finished_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String? accountId;
  final String? importBatchId;
  final RunTrigger trigger;
  final RunStatus status;
  final String? modelTag;
  final int totalCount;
  final int processedCount;
  final int assignedCount;
  final int deferredCount;
  final int failedCount;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;

  /// Progress in `[0,1]`. A run with nothing to do reads as complete rather
  /// than as an empty bar sitting at zero forever.
  double get progress => totalCount == 0
      ? 1
      : (processedCount / totalCount).clamp(0, 1).toDouble();

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategorizationRun &&
          other.id == id &&
          other.accountId == accountId &&
          other.importBatchId == importBatchId &&
          other.trigger == trigger &&
          other.status == status &&
          other.modelTag == modelTag &&
          other.totalCount == totalCount &&
          other.processedCount == processedCount &&
          other.assignedCount == assignedCount &&
          other.deferredCount == deferredCount &&
          other.failedCount == failedCount &&
          other.errorMessage == errorMessage &&
          other.startedAt == startedAt &&
          other.finishedAt == finishedAt &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    importBatchId,
    trigger,
    status,
    modelTag,
    totalCount,
    processedCount,
    assignedCount,
    deferredCount,
    failedCount,
    errorMessage,
    startedAt,
    finishedAt,
    createdAt,
  );
}

/// Whether stage 2 is available to this user at all: opted in *and* answering.
///
/// One value rather than two providers because every caller asks the same
/// question — "is there an AI to show?" — and a UI that renders proposals
/// because the setting is on, while the runtime is down, would promise
/// something that never arrives (see the ai-categorization skill's graceful
/// degradation rule).
@immutable
class AiAvailability {
  const AiAvailability({required this.enabled, required this.reachable});

  /// The safe default, and what a failed lookup resolves to: no AI UI at all.
  static const unavailable = AiAvailability(enabled: false, reachable: false);

  final bool enabled;
  final bool reachable;

  bool get isActive => enabled && reachable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiAvailability &&
          other.enabled == enabled &&
          other.reachable == reachable);

  @override
  int get hashCode => Object.hash(enabled, reachable);
}
