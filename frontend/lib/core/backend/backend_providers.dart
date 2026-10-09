import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_connection.dart';
import 'backend_locator.dart';
import 'backend_supervisor.dart';

/// The backend executable this app starts, or `null` when the packaged build
/// has none. `--dart-define=BASTIDE_BACKEND_EXECUTABLE=<path>` points a dev
/// build at a backend built locally.
final backendExecutableProvider = Provider<String?>((ref) {
  return locateBackendExecutable(
    appExecutable: Platform.resolvedExecutable,
    operatingSystem: Platform.operatingSystem,
    exists: (path) => File(path).existsSync(),
    override: const String.fromEnvironment('BASTIDE_BACKEND_EXECUTABLE'),
  );
});

/// One supervisor per backend launch. Invalidating it stops that backend;
/// the next read builds a fresh supervisor (see [BackendController.retry]).
final backendSupervisorProvider = Provider<BackendSupervisor>((ref) {
  final supervisor = BackendSupervisor(
    executable: ref.watch(backendExecutableProvider),
  );
  ref.onDispose(supervisor.stop);
  return supervisor;
});

/// The running backend. Loading while it starts; an error holding a
/// [BackendFailure] when it can't start, or when it dies later on.
class BackendController extends AsyncNotifier<BackendConnection> {
  @override
  Future<BackendConnection> build() async {
    final supervisor = ref.watch(backendSupervisorProvider);
    final connection = await supervisor.start();
    unawaited(
      supervisor.unexpectedExit.then((code) {
        if (!ref.mounted) return;
        state = AsyncError(
          BackendFailure(BackendFailureKind.crashed, exitCode: code),
          StackTrace.current,
        );
      }),
    );
    return connection;
  }

  /// Starts a new backend, after a failure.
  void retry() => ref.invalidate(backendSupervisorProvider);
}

final backendControllerProvider =
    AsyncNotifierProvider<BackendController, BackendConnection>(
      BackendController.new,
    );
