import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runs/run_event.dart';
import '../../../core/runs/run_progress_provider.dart';
import '../data/rule_packs_repository.dart';
import '../domain/rule_pack.dart';
import 'recategorized_reload.dart';
import 'rule_packs_controller.dart';
import 'rules_controller.dart';

/// What the import sheet knows about the import it started.
@immutable
class RulePackImportState {
  const RulePackImportState({this.isStarting = false, this.run, this.error});

  /// The start request is in flight.
  final bool isStarting;

  /// The import being followed, or the one that ended. `null` before
  /// « Importer ».
  final RulePackImportRun? run;

  /// The failure of the start request, or of re-reading the run.
  final Object? error;

  /// Started and not ended yet: the sheet locks its form.
  bool get isInFlight => isStarting || (run != null && !run!.status.isTerminal);

  /// The run has logos to download: the sheet shows the progress bar while
  /// it runs and the result in place once it is done. With none, the import
  /// ends as it always did, with a toast.
  bool get hasLogoDownloads => run != null && run!.logoTotal > 0;

  bool get isDownloading => hasLogoDownloads && !run!.status.isTerminal;

  /// The import's result, once it finished.
  RulePackImportResult? get result =>
      run?.status == RulePackImportRunStatus.finished ? run!.result : null;

  /// The run itself ended in failure (not a request that could not be made).
  bool get hasFailed => run?.status == RulePackImportRunStatus.failed;
}

/// Starts a pack import in the background and follows it to its end over the
/// run progress socket, the logo downloads step by step.
///
/// Progress comes from the socket's `rule_pack_import` events. The run's REST
/// snapshot is read when the socket cannot say on its own — a (re)connection
/// that does not know the run, a dropped socket — and once at the end, since
/// only the snapshot carries the result (failed logos included).
///
/// `autoDispose`: the subscription belongs to the sheet watching it.
class RulePackImportController extends Notifier<RulePackImportState> {
  StreamSubscription<RunUpdate>? _progress;
  bool _refreshing = false;
  bool _refreshAgain = false;

  @override
  RulePackImportState build() {
    ref.onDispose(_unwatch);
    return const RulePackImportState();
  }

  /// Imports a pack the user has seen the report for.
  ///
  /// [downloadLogos] lets the backend fetch the pack's linked logos from
  /// Wikimedia; off, only embedded logos are attached and nothing is fetched.
  Future<void> start(
    PendingRulePack pending, {
    bool applyNow = false,
    bool downloadLogos = false,
  }) async {
    if (state.isInFlight) return;
    state = const RulePackImportState(isStarting: true);
    try {
      final run = await ref
          .read(rulePacksRepositoryProvider)
          .startImport(
            pack: pending.pack,
            builtinId: pending.builtinId,
            applyNow: applyNow,
            downloadLogos: downloadLogos,
          );
      if (!ref.mounted) return;
      state = RulePackImportState(run: run);
      await _onRunChanged(run);
    } catch (error) {
      if (!ref.mounted) return;
      state = RulePackImportState(error: error);
    }
  }

  void _apply(RulePackImportRun next) {
    final current = state.run;
    if (current != null && current.id == next.id && _isStale(current, next)) {
      return;
    }
    state = RulePackImportState(run: next);
    unawaited(_onRunChanged(next));
  }

  /// A REST read can land after a socket event that is newer than it; never
  /// let it move the run backwards.
  static bool _isStale(RulePackImportRun current, RulePackImportRun next) {
    if (current.status.isTerminal) return true;
    return !next.status.isTerminal && next.logoDone < current.logoDone;
  }

  Future<void> _onRunChanged(RulePackImportRun run) async {
    if (!run.status.isTerminal) {
      _watch(run.id);
      return;
    }
    _unwatch();
    // The rules are written before the logos are fetched, so even a failed
    // run may have created some: the list is reloaded either way.
    ref.invalidate(rulesControllerProvider);
    // A bundled pack is recorded as imported with its rules: stop offering it.
    ref.invalidate(builtinPacksProvider);
    if ((run.result?.recategorizedCount ?? 0) > 0) {
      await reloadRecategorizedViews(ref);
    }
  }

  void _watch(String runId) {
    if (_progress != null) return;
    _progress = ref
        .read(runProgressClientProvider)
        .watch(runId)
        .listen(_onUpdate);
  }

  void _unwatch() {
    final progress = _progress;
    _progress = null;
    if (progress != null) unawaited(progress.cancel());
  }

  void _onUpdate(RunUpdate update) {
    switch (update) {
      case RunEventUpdate(:final event):
        _onEvent(event);
      case RunResync(:final latest):
        // Not on the bus: not started yet, or ended while no socket was open.
        // Only the snapshot can tell which.
        if (latest == null) {
          unawaited(_refresh());
        } else {
          _onEvent(latest);
        }
      case RunConnectionLost():
        unawaited(_refresh());
    }
  }

  void _onEvent(RunEvent event) {
    final current = state.run;
    if (current == null ||
        current.id != event.runId ||
        current.status.isTerminal) {
      return;
    }
    // A terminal event leaves the run running until the snapshot answers: the
    // event says the run ended, but only the snapshot carries what it did.
    _apply(current.withProgress(logoDone: event.done, logoTotal: event.total));
    if (event.type.isTerminal) unawaited(_refresh());
  }

  /// Re-reads the run's snapshot, one request at a time.
  Future<void> _refresh() async {
    final current = state.run;
    if (current == null) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final run = await ref
          .read(rulePacksRepositoryProvider)
          .getImportRun(current.id);
      if (!ref.mounted) return;
      _apply(run);
    } catch (error) {
      // Not reaching the sidecar is not the import failing: it runs
      // server-side and may well finish. Say so; the socket's next
      // (re)connection reads again.
      if (!ref.mounted) return;
      state = RulePackImportState(run: state.run, error: error);
    } finally {
      _refreshing = false;
      if (_refreshAgain && ref.mounted) {
        _refreshAgain = false;
        unawaited(_refresh());
      }
    }
  }
}

final rulePackImportControllerProvider =
    NotifierProvider<RulePackImportController, RulePackImportState>(
      RulePackImportController.new,
      isAutoDispose: true,
    );
