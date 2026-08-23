import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categorization/application/run_controller.dart';
import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

/// How long an edit waits before it becomes a `PATCH /settings`.
///
/// The card has no save button, so every keystroke in the address field and
/// every pixel of a slider drag is a candidate request. Edits inside the window
/// coalesce into one body, which is why dragging the slider does not fire a
/// patch per pixel.
const settingsPatchDebounce = Duration(milliseconds: 350);

/// The state of the link to the local runtime, as one value.
///
/// One enum rather than an `aiEnabled` flag beside a `reachable` flag: those
/// two booleans have a fourth combination — off *and* connected — that the card
/// has no treatment for, and rendering it would tell the user the engine is
/// classifying when nothing is.
enum InferenceConnection {
  /// The user has not opted in, and nothing has been probed since.
  disabled,

  /// A probe answered: the runtime is up and listed its models.
  reachable,

  /// A probe was made and nothing answered at that address.
  unreachable;

  bool get isReachable => this == InferenceConnection.reachable;

  bool get isUnreachable => this == InferenceConnection.unreachable;
}

/// Everything the local-AI card renders.
@immutable
class SettingsState {
  const SettingsState({
    required this.settings,
    required this.connection,
    this.models = const [],
    this.isProbing = false,
    this.baseUrlError,
  });

  final UserSettings settings;

  final InferenceConnection connection;

  /// Tags the last successful probe reported, in the runtime's own order.
  final List<String> models;

  /// A probe is in flight. Carried separately from [connection] because the
  /// probe reports its progress on its own button — the card keeps rendering
  /// the last known connection underneath rather than blanking out.
  final bool isProbing;

  /// The failure of the last patch that carried the engine address, left raw
  /// for the card to localize onto that field. The loopback-only rule is a 422
  /// (`P2-01`), and it is the one validation the user has to be able to read
  /// and act on.
  final Object? baseUrlError;

  /// The threshold as the whole percent the slider works in.
  int get thresholdPercent => settings.confidenceThresholdPercent;

  SettingsState copyWith({
    UserSettings? settings,
    InferenceConnection? connection,
    List<String>? models,
    bool? isProbing,
    Object? baseUrlError,
    bool clearBaseUrlError = false,
  }) => SettingsState(
    settings: settings ?? this.settings,
    connection: connection ?? this.connection,
    models: models ?? this.models,
    isProbing: isProbing ?? this.isProbing,
    baseUrlError: clearBaseUrlError ? null : (baseUrlError ?? this.baseUrlError),
  );
}

/// Loads `/settings`, patches edits back with a debounce, and probes the
/// runtime.
///
/// The card is presentation-only: it renders [SettingsState] and calls these
/// methods. In particular the percentage/`[0,1]` threshold conversion and the
/// choice of which connection state to show both live here, so no two widgets
/// can ever disagree about either.
class SettingsController extends AsyncNotifier<SettingsState> {
  Timer? _debounce;

  // Edits made since the last flush; `null` means "untouched", which is also
  // what the repository reads as "do not send this field". Four typed slots
  // rather than a map of wire names keeps the JSON vocabulary in `data/`.
  bool? _pendingAiEnabled;
  String? _pendingBaseUrl;
  String? _pendingModelTag;
  double? _pendingThreshold;

  bool get _hasPendingEdits =>
      _pendingAiEnabled != null ||
      _pendingBaseUrl != null ||
      _pendingModelTag != null ||
      _pendingThreshold != null;

  /// Drops replies from a probe the user has already superseded — changing the
  /// address twice quickly would otherwise let the first answer land last.
  int _probeId = 0;

  @override
  Future<SettingsState> build() async {
    ref.onDispose(() => _debounce?.cancel());

    final settings = await ref.read(settingsRepositoryProvider).read();
    // Probe on mount, but only once the user has opted in: an absent runtime is
    // the default state, and dialing one nobody asked for costs a round trip to
    // learn nothing.
    if (!settings.aiEnabled) {
      return SettingsState(settings: settings, connection: InferenceConnection.disabled);
    }
    return _withHealth(settings, await _safeProbe());
  }

  /// Opts in or out. Not debounced: a toggle is a decision, not typing, and it
  /// changes what the review queue renders (`P2-08`), which should follow the
  /// switch immediately.
  Future<void> setAiEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;

    // Turning off drops the last probe result with it, so the status row can
    // never keep claiming a connection for an engine nothing is using.
    state = AsyncData(
      current.copyWith(
        settings: current.settings.copyWith(aiEnabled: enabled),
        connection: enabled ? current.connection : InferenceConnection.disabled,
        models: enabled ? current.models : const [],
      ),
    );

    _debounce?.cancel();
    _pendingAiEnabled = enabled;
    await _flush();
    if (enabled) await probe();
  }

  /// The engine address. Debounced, then probed — the backend dials whatever it
  /// has *stored*, so the probe has to follow the patch rather than race it.
  void setBaseUrl(String value) {
    _pendingBaseUrl = value;
    _edit(
      (settings) => settings.copyWith(inferenceBaseUrl: value),
      clearsBaseUrlError: true,
    );
  }

  /// The model tag, whether picked from the probe's list or typed by hand.
  void setModelTag(String value) {
    _pendingModelTag = value;
    _edit((settings) => settings.copyWith(modelTag: value));
  }

  /// The confidence floor, taken from the slider as a whole percent and stored
  /// as the `[0,1]` real the API defines.
  void setThresholdPercent(int percent) {
    final threshold = UserSettings.thresholdFromPercent(percent);
    _pendingThreshold = threshold;
    _edit((settings) => settings.copyWith(confidenceThreshold: threshold));
  }

  /// Probes the runtime the backend currently has stored.
  ///
  /// Flushes any pending edit first: testing the address the user just typed
  /// means the backend has to have been told about it.
  Future<void> probe() async {
    if (state.value == null) return;

    await _flush();
    final before = state.value;
    if (before == null) return;

    state = AsyncData(before.copyWith(isProbing: true));
    final probeId = ++_probeId;
    final health = await _safeProbe();
    if (probeId != _probeId) return;

    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(_withHealth(latest.settings, health, from: latest));
    _syncReviewQueue();
  }

  /// Applies an edit locally, then schedules the patch that persists it.
  void _edit(
    UserSettings Function(UserSettings) apply, {
    bool clearsBaseUrlError = false,
  }) {
    final current = state.value;
    if (current == null) return;

    // Optimistic: the field the user is typing in must not wait a round trip to
    // show what they typed.
    state = AsyncData(
      current.copyWith(
        settings: apply(current.settings),
        clearBaseUrlError: clearsBaseUrlError,
      ),
    );

    _debounce?.cancel();
    _debounce = Timer(settingsPatchDebounce, () => unawaited(_flushThenProbe()));
  }

  Future<void> _flushThenProbe() async {
    final probesAddress = _pendingBaseUrl != null;
    final accepted = await _flush();
    if (accepted && probesAddress && (state.value?.settings.aiEnabled ?? false)) {
      await probe();
    }
  }

  /// Sends the coalesced edits. Returns whether they were accepted.
  Future<bool> _flush() async {
    _debounce?.cancel();
    _debounce = null;
    if (!_hasPendingEdits) return true;

    final aiEnabled = _pendingAiEnabled;
    final baseUrl = _pendingBaseUrl;
    final modelTag = _pendingModelTag;
    final threshold = _pendingThreshold;
    _pendingAiEnabled = null;
    _pendingBaseUrl = null;
    _pendingModelTag = null;
    _pendingThreshold = null;

    if (state.value == null) return false;

    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .update(
            aiEnabled: aiEnabled,
            inferenceBaseUrl: baseUrl,
            modelTag: modelTag,
            confidenceThreshold: threshold,
          );
      final latest = state.value;
      if (latest == null) return false;
      state = AsyncData(latest.copyWith(settings: saved, clearBaseUrlError: true));
      if (aiEnabled != null) _syncReviewQueue();
      return true;
    } catch (error) {
      final latest = state.value;
      if (latest == null) return false;
      // A rejected patch is not a broken screen — the card stays usable, still
      // showing the refused value, so the user can correct it.
      state = AsyncData(
        baseUrl != null ? latest.copyWith(baseUrlError: error) : latest,
      );
      return false;
    }
  }

  /// A probe never throws: an unreachable runtime is a normal, reportable state
  /// and a sidecar that could not be asked reads the same way to the user.
  Future<InferenceHealth> _safeProbe() async {
    try {
      return await ref.read(settingsRepositoryProvider).probe();
    } catch (_) {
      return InferenceHealth.unreachable;
    }
  }

  SettingsState _withHealth(
    UserSettings settings,
    InferenceHealth health, {
    SettingsState? from,
  }) => SettingsState(
    settings: settings,
    connection: health.reachable
        ? InferenceConnection.reachable
        : InferenceConnection.unreachable,
    models: health.models,
    baseUrlError: from?.baseUrlError,
  );

  /// Makes the review queue re-ask whether there is an AI to show.
  ///
  /// Step 8 of the card: turning the toggle off has to return `07` to its
  /// Phase 1 rendering with the calm invitation, not merely persist a boolean —
  /// and that queue reads its answer from [aiAvailabilityProvider], which
  /// caches until something invalidates it.
  void _syncReviewQueue() => ref.invalidate(aiAvailabilityProvider);
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(SettingsController.new);
