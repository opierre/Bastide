import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runs/run_event.dart';
import '../../../core/runs/run_progress_provider.dart';
import '../../transactions/application/transactions_controller.dart';
import '../data/categorization_repository.dart';
import '../domain/categorization_run.dart';

/// What the review queue knows about the current run.
@immutable
class RunState {
  const RunState({
    this.run,
    this.isStarting = false,
    this.error,
    this.isBannerDismissed = false,
  });

  /// The run being followed, or the last one that finished. `null` before the
  /// user has asked for one this session.
  final CategorizationRun? run;

  /// A start or cancel request is in flight.
  final bool isStarting;

  /// The failure of the last start/cancel, or of re-reading the run. Reported
  /// plainly beside the queue, never as an error wall — the queue works
  /// without a run.
  final Object? error;

  /// The user closed the terminal banner. Kept in state rather than in the
  /// banner's own `State` so the banner does not come back on every list
  /// refresh.
  final bool isBannerDismissed;

  bool get isRunning => run != null && run!.status.isInFlight;

  RunState copyWith({
    CategorizationRun? run,
    bool? isStarting,
    Object? error,
    bool clearError = false,
    bool? isBannerDismissed,
  }) => RunState(
    run: run ?? this.run,
    isStarting: isStarting ?? this.isStarting,
    error: clearError ? null : (error ?? this.error),
    isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
  );
}

/// Starts a categorization run and follows it to a terminal status over the
/// run progress socket.
///
/// Progress comes from the socket's events; the run's REST snapshot
/// (`GET /categorization/runs/{id}`) is read only when the socket cannot say
/// on its own — on a (re)connection that does not know the run, after the
/// socket failed or dropped, and once at the end for the authoritative final
/// row. There is no timer.
///
/// `autoDispose` on purpose: the subscription belongs to the panel that is
/// watching it, and the shared socket closes once nobody watches any run.
class RunController extends Notifier<RunState> {
  StreamSubscription<RunUpdate>? _progress;
  bool _refreshing = false;

  /// A re-read was asked for while one was in flight; run another after it,
  /// so the last answer applied is never older than the last reason to ask.
  bool _refreshAgain = false;

  /// The current [RunState.error] was set by a failed re-read, so a later
  /// successful one may clear it. An error from start/cancel is left alone.
  bool _errorFromRefresh = false;

  @override
  RunState build() {
    ref.onDispose(_unwatch);
    return const RunState();
  }

  /// Asks for a run over [scope]. Requesting one while another is in flight
  /// returns the in-flight run, so this is also how the panel
  /// re-attaches to a run it already started.
  Future<void> start({
    String? accountId,
    RunScope scope = RunScope.pending,
  }) async {
    if (state.isStarting || state.isRunning) return;
    state = state.copyWith(
      isStarting: true,
      clearError: true,
      isBannerDismissed: false,
    );
    _errorFromRefresh = false;
    try {
      final run = await ref
          .read(categorizationRepositoryProvider)
          .startRun(accountId: accountId, scope: scope);
      _unwatch();
      state = RunState(run: run);
      _onRunChanged(previous: null, next: run);
    } catch (error) {
      state = state.copyWith(isStarting: false, error: error);
    }
  }

  /// Cancels the run in flight. The executor stops after the batch it is on;
  /// the response already carries the cancelled run.
  Future<void> cancel() async {
    final current = state.run;
    if (current == null || current.status.isTerminal) return;
    try {
      final cancelled = await ref
          .read(categorizationRepositoryProvider)
          .cancelRun(current.id);
      _apply(cancelled);
    } catch (error) {
      _errorFromRefresh = false;
      state = state.copyWith(error: error);
    }
  }

  void dismissBanner() => state = state.copyWith(isBannerDismissed: true);

  void _apply(CategorizationRun next) {
    final previous = state.run;
    if (previous != null &&
        previous.id == next.id &&
        _isStale(previous, next)) {
      return;
    }
    state = state.copyWith(run: next, isStarting: false);
    _onRunChanged(previous: previous, next: next);
  }

  /// A REST read can land after a socket event that is newer than it; never
  /// let it move the run backwards.
  bool _isStale(CategorizationRun current, CategorizationRun next) {
    if (current.status.isTerminal) return next.status.isInFlight;
    return next.status.isInFlight &&
        next.processedCount < current.processedCount;
  }

  /// Keeps the subscription in step with the status, and the transaction list
  /// in step with the rows the run has committed.
  void _onRunChanged({
    required CategorizationRun? previous,
    required CategorizationRun next,
  }) {
    if (next.status.isTerminal) {
      _unwatch();
    } else {
      _watch(next.id);
    }

    // Progress is committed per batch, so a moved `processed_count` means rows
    // have actually changed server-side — that is what lets rows leave the
    // queue while the user watches. A terminal status refreshes once more, for
    // the last batch.
    final advanced =
        previous == null || previous.processedCount != next.processedCount;
    final finished =
        previous != null &&
        previous.status.isInFlight &&
        next.status.isTerminal;
    if (advanced || finished) {
      unawaited(
        ref.read(transactionsControllerProvider.notifier).refreshQuietly(),
      );
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
        // Not on the bus: either not started yet or it ended while no socket
        // was open. Only the REST snapshot can tell which.
        if (latest == null) {
          unawaited(_refresh());
        } else {
          _onEvent(latest);
        }
      case RunConnectionLost():
        // Events may be lost until the socket is back; one read per failed
        // attempt (spaced by the client's backoff) keeps the banner honest,
        // and catches a run that ended meanwhile.
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
    _apply(
      current.withProgress(
        status: _statusOf(event, current),
        totalCount: event.total,
        processedCount: event.done,
        assignedCount: event.counts['assigned'],
        deferredCount: event.counts['deferred'],
        failedCount: event.counts['failed'],
        errorMessage: event.errorMessage,
      ),
    );
    // The event says the run ended, not which terminal status it ended in
    // (success vs partial) nor its message: read the final row once.
    if (event.type.isTerminal) unawaited(_refresh());
  }

  static RunStatus _statusOf(RunEvent event, CategorizationRun current) =>
      switch (event.type) {
        RunEventType.started || RunEventType.progress => RunStatus.running,
        RunEventType.finished =>
          (event.counts['failed'] ?? current.failedCount) > 0
              ? RunStatus.partial
              : RunStatus.success,
        RunEventType.failed => RunStatus.failed,
        RunEventType.cancelled => RunStatus.cancelled,
      };

  /// Re-reads the run's REST snapshot, one request at a time.
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
          .read(categorizationRepositoryProvider)
          .getRun(current.id);
      if (!ref.mounted) return;
      if (_errorFromRefresh) {
        state = state.copyWith(clearError: true);
        _errorFromRefresh = false;
      }
      _apply(run);
    } catch (error) {
      // Not reaching the sidecar is not the run failing — the run is
      // server-side and may well finish. Say so, and let the socket's next
      // (re)connection try again.
      if (!ref.mounted) return;
      _errorFromRefresh = true;
      state = state.copyWith(error: error);
    } finally {
      _refreshing = false;
      if (_refreshAgain && ref.mounted) {
        _refreshAgain = false;
        unawaited(_refresh());
      }
    }
  }
}

final runControllerProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
  isAutoDispose: true,
);

/// Whether to show any stage-2 UI at all.
///
/// Resolves to [AiAvailability.unavailable] on failure rather than surfacing an
/// error: the app is fully usable with no runtime, and a broken health probe
/// must never become an error wall over the review queue (ai-categorization
/// skill, graceful degradation).
final aiAvailabilityProvider = FutureProvider<AiAvailability>((ref) async {
  try {
    return await ref.read(categorizationRepositoryProvider).readAvailability();
  } catch (_) {
    return AiAvailability.unavailable;
  }
});
