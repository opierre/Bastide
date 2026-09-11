import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_controller.dart';
import '../data/categorization_repository.dart';
import '../domain/categorization_run.dart';

/// How often an in-flight run is re-read.
///
/// Two seconds is slow enough that a run of a few hundred rows costs a few
/// dozen requests to a process on loopback, and fast enough that the count in
/// the banner moves while the user is looking at it.
const runPollInterval = Duration(seconds: 2);

/// What the review queue knows about the current run.
@immutable
class RunState {
  const RunState({this.run, this.isStarting = false, this.error, this.isBannerDismissed = false});

  /// The run being polled, or the last one that finished. `null` before the
  /// user has asked for one this session.
  final CategorizationRun? run;

  /// A start or cancel request is in flight.
  final bool isStarting;

  /// The failure of the last start/cancel. Reported plainly beside the queue,
  /// never as an error wall — the queue works without a run.
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

/// Starts a categorization run and polls it to a terminal status.
///
/// `autoDispose` on purpose: the timer belongs to the panel that is watching
/// it. A poll that outlived the review queue would keep talking to the sidecar
/// about a run nobody is looking at, forever.
class RunController extends Notifier<RunState> {
  Timer? _poll;

  @override
  RunState build() {
    ref.onDispose(_stopPolling);
    return const RunState();
  }

  /// Asks for a run over [scope]. Requesting one while another is in flight
  /// returns the in-flight run (PROJECT.md §7), so this is also how the panel
  /// re-attaches to a run it already started.
  Future<void> start({String? accountId, RunScope scope = RunScope.pending}) async {
    if (state.isStarting || state.isRunning) return;
    state = state.copyWith(isStarting: true, clearError: true, isBannerDismissed: false);
    try {
      final run = await ref.read(categorizationRepositoryProvider).startRun(
        accountId: accountId,
        scope: scope,
      );
      state = RunState(run: run);
      _onRunChanged(previous: null, next: run);
    } catch (error) {
      state = state.copyWith(isStarting: false, error: error);
    }
  }

  /// Cancels the run in flight. The executor stops after the batch it is on,
  /// so the poll keeps going until the status actually turns.
  Future<void> cancel() async {
    final current = state.run;
    if (current == null || current.status.isTerminal) return;
    try {
      final cancelled = await ref.read(categorizationRepositoryProvider).cancelRun(current.id);
      _apply(cancelled);
    } catch (error) {
      state = state.copyWith(error: error);
    }
  }

  void dismissBanner() => state = state.copyWith(isBannerDismissed: true);

  void _apply(CategorizationRun next) {
    final previous = state.run;
    state = state.copyWith(run: next, isStarting: false);
    _onRunChanged(previous: previous, next: next);
  }

  /// Keeps the timer in step with the status, and the transaction list in step
  /// with the rows the run has committed.
  void _onRunChanged({required CategorizationRun? previous, required CategorizationRun next}) {
    if (next.status.isTerminal) {
      _stopPolling();
    } else {
      _startPolling();
    }

    // Progress is committed per batch, so a moved `processed_count` means rows
    // have actually changed server-side — that is what lets rows leave the
    // queue while the user watches. A terminal status refreshes once more, for
    // the last batch.
    final advanced = previous == null || previous.processedCount != next.processedCount;
    final finished = previous != null && previous.status.isInFlight && next.status.isTerminal;
    if (advanced || finished) {
      unawaited(ref.read(transactionsControllerProvider.notifier).refreshQuietly());
    }
  }

  void _startPolling() {
    if (_poll != null) return;
    _poll = Timer.periodic(runPollInterval, (_) => unawaited(_tick()));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _tick() async {
    final current = state.run;
    if (current == null || current.status.isTerminal) {
      _stopPolling();
      return;
    }
    try {
      _apply(await ref.read(categorizationRepositoryProvider).getRun(current.id));
    } catch (error) {
      // A poll that can't reach the sidecar is not the run failing — the run is
      // server-side and may well finish. Stop asking, and say so.
      _stopPolling();
      state = state.copyWith(error: error);
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
