import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_runtime_repository.dart';
import '../domain/local_runtime.dart';

/// How often a running download is asked for its progress.
const localRuntimePollInterval = Duration(seconds: 1);

/// The downloadable engine: its status, and the download the user starts,
/// cancels or undoes from the « IA locale » card.
///
/// The download itself runs in the backend, which keeps going whether or not
/// this screen is open; this controller only follows it, polling while it runs
/// and stopping as soon as it doesn't.
class LocalRuntimeController extends AsyncNotifier<LocalRuntime> {
  Timer? _poll;

  LocalRuntimeRepository get _repository =>
      ref.read(localRuntimeRepositoryProvider);

  @override
  Future<LocalRuntime> build() async {
    ref.onDispose(_stopPolling);
    return _follow(await _repository.read());
  }

  /// Starts the download, or resumes the one a cancel or a failure left.
  Future<void> download() => _act(_repository.download);

  Future<void> cancel() => _act(_repository.cancel);

  /// Deletes the engine and its model, giving the disk space back.
  Future<void> remove() => _act(_repository.remove);

  Future<void> _act(Future<LocalRuntime> Function() call) async {
    try {
      state = AsyncData(_follow(await call()));
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  LocalRuntime _follow(LocalRuntime runtime) {
    if (runtime.state == LocalRuntimeState.downloading) {
      _poll ??= Timer.periodic(
        localRuntimePollInterval,
        (_) => unawaited(_tick()),
      );
    } else {
      _stopPolling();
    }
    return runtime;
  }

  Future<void> _tick() async {
    try {
      state = AsyncData(_follow(await _repository.read()));
    } catch (error, stack) {
      // The sidecar not answering is not the download failing: stop asking
      // rather than hammer it, and let the card offer a retry.
      _stopPolling();
      state = AsyncError(error, stack);
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }
}

final localRuntimeControllerProvider =
    AsyncNotifierProvider<LocalRuntimeController, LocalRuntime>(
      LocalRuntimeController.new,
    );
