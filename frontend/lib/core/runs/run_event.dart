import 'package:flutter/foundation.dart';

/// The step a [RunEvent] reports — the backend's `RunEventType` literals
/// (`backend/app/core/progress.py`).
enum RunEventType {
  /// The run opened on the bus.
  started,
  progress,

  /// The run got to the end. Whether every unit succeeded is the run's own
  /// business: read it from the run's REST snapshot.
  finished,
  failed,
  cancelled;

  /// `null` for a value this build does not know, so a newer backend can add
  /// one without breaking older clients.
  static RunEventType? fromWire(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }

  bool get isTerminal =>
      this == RunEventType.finished ||
      this == RunEventType.failed ||
      this == RunEventType.cancelled;
}

/// One step of one background run, as the progress socket pushes it.
///
/// Generic over the kind of run: [kind] stays a plain string (`categorization`,
/// `rule_pack_import`, …) so a kind added on the backend never breaks parsing,
/// and [counts] carries the kind's own tallies without this class knowing what
/// they mean.
@immutable
class RunEvent {
  const RunEvent({
    required this.runId,
    required this.kind,
    required this.type,
    required this.done,
    required this.total,
    this.counts = const {},
    this.errorMessage,
    required this.occurredAt,
  });

  /// Parses one wire event; `null` when it is malformed or its `event` value is
  /// unknown, so one odd message is skipped rather than ending the stream.
  static RunEvent? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final type = RunEventType.fromWire(json['event']);
    final runId = json['run_id'];
    final kind = json['kind'];
    final done = json['done'];
    final total = json['total'];
    final occurredAt = json['occurred_at'];
    if (type == null ||
        runId is! String ||
        kind is! String ||
        done is! int ||
        total is! int ||
        occurredAt is! String) {
      return null;
    }
    final rawCounts = json['counts'];
    final counts = <String, int>{
      if (rawCounts is Map<String, dynamic>)
        for (final entry in rawCounts.entries)
          if (entry.value is int) entry.key: entry.value as int,
    };
    final errorMessage = json['error_message'];
    final parsedAt = DateTime.tryParse(occurredAt);
    if (parsedAt == null) return null;
    return RunEvent(
      runId: runId,
      kind: kind,
      type: type,
      done: done,
      total: total,
      counts: Map.unmodifiable(counts),
      errorMessage: errorMessage is String ? errorMessage : null,
      occurredAt: parsedAt,
    );
  }

  final String runId;

  /// The kind of run (`categorization`, …). Unknown kinds are kept as is.
  final String kind;
  final RunEventType type;

  /// Units of work done out of [total], in the run's own unit (rows, logos…).
  final int done;
  final int total;

  /// Kind-specific tallies, e.g. `assigned`/`deferred`/`failed` for a
  /// categorization run. A missing key reads as absent, not zero.
  final Map<String, int> counts;

  /// Set on [RunEventType.failed] only: what went wrong, user-safe.
  final String? errorMessage;
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunEvent &&
          other.runId == runId &&
          other.kind == kind &&
          other.type == type &&
          other.done == done &&
          other.total == total &&
          mapEquals(other.counts, counts) &&
          other.errorMessage == errorMessage &&
          other.occurredAt == occurredAt);

  @override
  int get hashCode => Object.hash(
    runId,
    kind,
    type,
    done,
    total,
    Object.hashAllUnordered(
      counts.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    errorMessage,
    occurredAt,
  );

  @override
  String toString() => 'RunEvent($kind $runId ${type.name} $done/$total)';
}

/// What a watcher of one run hears from [RunProgressClient.watch].
@immutable
sealed class RunUpdate {
  const RunUpdate();
}

/// The run published a step.
final class RunEventUpdate extends RunUpdate {
  const RunEventUpdate(this.event);

  final RunEvent event;
}

/// The socket is (re)connected and this is everything it knows of the run.
///
/// [latest] is the run's last event when it is active on the bus (or ended
/// while this client was listening). `null` means the bus has nothing on it:
/// the run has not started yet, or it ended while no socket was open. Either
/// way the watcher should re-read the run's REST snapshot once to find out.
final class RunResync extends RunUpdate {
  const RunResync(this.latest);

  final RunEvent? latest;
}

/// The socket could not connect, or dropped. The client is already retrying
/// with backoff; meanwhile events may be missed, so a watcher that must not
/// stall can re-read the run's REST snapshot. [unauthenticated] is set when
/// the client has no usable bearer token — signed out, or refused by the
/// backend (close code 4401, e.g. after a logout): that client never retries,
/// and the next login brings a new one.
final class RunConnectionLost extends RunUpdate {
  const RunConnectionLost({this.unauthenticated = false});

  final bool unauthenticated;
}
