import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rules_repository.dart';
import '../domain/rule.dart';

/// How long the editor waits after the last keystroke before asking the
/// sidecar. A preview that fired per keystroke would run a full table scan for
/// every letter of « CARREFOUR ».
const rulePreviewDebounce = Duration(milliseconds: 350);

/// What the editor's match preview currently knows.
@immutable
class RulePreviewState {
  const RulePreviewState({this.isLoading = false, this.preview, this.error});

  final bool isLoading;
  final RulePreview? preview;

  /// The failure the last request came back with. Left raw for the editor to
  /// localize: an uncompilable `regex` (`RULE_PATTERN_INVALID`) belongs on the
  /// pattern field, and everything else is a preview that simply couldn't run
  /// — telling those apart is what stops "not a valid pattern" from rendering
  /// as "matches 0 transactions".
  final Object? error;

  bool get isIdle => !isLoading && preview == null && error == null;
}

/// Runs `POST /rules/preview` for the condition being typed, debounced.
///
/// Lives in the controller rather than in the modal's `State` so the editor
/// stays presentation-only, and so a stale reply can be dropped: responses are
/// matched against the request that is current when they land, which a widget
/// doing its own `Future` bookkeeping routinely gets wrong when the user
/// switches match type mid-flight.
class RulePreviewController extends Notifier<RulePreviewState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  RulePreviewState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const RulePreviewState();
  }

  /// Schedules a preview for [pattern]. An empty pattern clears the banner
  /// rather than asking the backend to count everything.
  void request({
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
  }) {
    _debounce?.cancel();
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }

    state = RulePreviewState(isLoading: true, preview: state.preview);
    _debounce = Timer(rulePreviewDebounce, () {
      unawaited(_run(matchField, matchType, trimmed));
    });
  }

  void clear() {
    _debounce?.cancel();
    _requestId++;
    state = const RulePreviewState();
  }

  Future<void> _run(
    RuleMatchField matchField,
    RuleMatchType matchType,
    String pattern,
  ) async {
    final requestId = ++_requestId;
    try {
      final preview = await ref
          .read(rulesRepositoryProvider)
          .preview(matchField: matchField, matchType: matchType, pattern: pattern);
      if (requestId != _requestId) return;
      state = RulePreviewState(preview: preview);
    } catch (error) {
      if (requestId != _requestId) return;
      state = RulePreviewState(error: error);
    }
  }
}

final rulePreviewControllerProvider =
    NotifierProvider<RulePreviewController, RulePreviewState>(
      RulePreviewController.new,
    );
