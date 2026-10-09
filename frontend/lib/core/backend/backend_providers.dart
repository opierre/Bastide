import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backend_connection.dart';
import 'backend_locator.dart';
import 'backend_supervisor.dart';
import 'data_dir.dart';
import 'external_backend.dart';

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

/// A backend already running that the app uses instead of starting its own
/// (dev mode, see [resolveExternalBackend]); `null` in a packaged build.
final externalBackendProvider = Provider<ExternalBackend?>((ref) {
  return resolveExternalBackend(
    url: const String.fromEnvironment('BASTIDE_BACKEND_URL'),
    sessionToken: const String.fromEnvironment('BASTIDE_SESSION_TOKEN'),
    debug: kDebugMode,
    packagedBackendFound: ref.watch(backendExecutableProvider) != null,
  );
});

/// How an external backend is checked; replaced in tests.
final externalBackendProbeProvider =
    Provider<Future<BackendConnection> Function(ExternalBackend backend)>(
      (ref) => probeExternalBackend,
    );

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
    final external = ref.watch(externalBackendProvider);
    if (external != null) {
      return ref.watch(externalBackendProbeProvider)(external);
    }

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

  /// Starts a new backend after a failure (or checks the external one again).
  void retry() {
    ref.invalidate(backendSupervisorProvider);
    ref.invalidateSelf();
  }
}

/// Never retried automatically, unlike Riverpod's default: a backend that
/// failed to start is restarted only when the user asks, since relaunching it
/// on its own would repeat a backup and migration attempt, or hide that the
/// database is from a newer version.
final backendControllerProvider =
    AsyncNotifierProvider<BackendController, BackendConnection>(
      BackendController.new,
      retry: (_, _) => null,
    );

/// The backend's data folder (see [bastideDataDir]).
final dataDirProvider = Provider<String?>((ref) {
  return bastideDataDir(
    operatingSystem: Platform.operatingSystem,
    environment: Platform.environment,
  );
});

/// Opens the backend's logs folder in the OS file manager — the data folder
/// itself when the backend never got far enough to create `logs/`.
final openLogsFolderProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final dataDir = ref.read(dataDirProvider);
    if (dataDir == null) return;
    final logs = Directory('$dataDir${Platform.pathSeparator}logs');
    final folder = logs.existsSync() ? logs.path : dataDir;
    await launchUrl(Uri.directory(folder));
  };
});
