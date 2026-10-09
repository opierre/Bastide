import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'backend_connection.dart';

/// Starts a process; [Process.start] in the app, a fake in tests.
typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    });

Future<Process> _defaultStartProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.start(executable, arguments, environment: environment);

/// A fresh, unguessable token for one launch: 32 random bytes, base64url.
String generateSessionToken([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// The exit code the backend uses when the database is newer than the build
/// (`EXIT_SCHEMA_TOO_NEW` in `backend/app/cli.py`).
const exitSchemaTooNew = 10;

/// What `bastide-backend` prints on stderr in that case.
const _fatalSchemaTooNew = 'FATAL DATABASE_SCHEMA_TOO_NEW';

final _readyLine = RegExp(r'^READY (\d{1,5}) (\S+)$');

/// Starts the frozen backend and waits for its handshake.
///
/// The backend picks a free loopback port (`--port 0`), runs its backup and
/// migrations, then prints `READY <port> <version>` on stdout. The session
/// token travels in the environment rather than argv, which other processes
/// on the machine can read. `--exit-on-stdin-close` makes the backend exit
/// when this app does: the OS closes our end of the pipe even on a crash.
class BackendSupervisor {
  BackendSupervisor({
    required this.executable,
    ProcessStarter? startProcess,
    String Function()? generateToken,
    this.readyTimeout = const Duration(seconds: 60),
    this.onStarted,
  }) : _startProcess = startProcess ?? _defaultStartProcess,
       _generateToken = generateToken ?? generateSessionToken;

  /// The backend to run; `null` when none was found, which [start] reports
  /// as [BackendFailureKind.notFound].
  final String? executable;

  /// Long enough for a first launch that backs up and migrates a large
  /// database while an antivirus scans every file the frozen build loads.
  final Duration readyTimeout;

  /// Called with the process as soon as it exists, before the handshake —
  /// where the Windows build ties it to a job object.
  final void Function(Process process)? onStarted;

  final ProcessStarter _startProcess;
  final String Function() _generateToken;

  Process? _process;
  Completer<int>? _unexpectedExit;

  /// Completes with the exit code if the backend exits without [stop] being
  /// called — a crash once it was ready. Never completes otherwise.
  Future<int> get unexpectedExit {
    final exit = _unexpectedExit;
    if (exit == null) throw StateError('The backend was not started.');
    return exit.future;
  }

  /// Starts the backend and completes once it is ready to serve.
  ///
  /// Throws a [BackendFailure] if it can't be started, exits first, prints
  /// something other than the handshake, or stays silent past [readyTimeout].
  Future<BackendConnection> start() async {
    final executable = this.executable;
    if (executable == null) {
      throw const BackendFailure(BackendFailureKind.notFound);
    }
    final token = _generateToken();

    final Process process;
    try {
      process = await _startProcess(
        executable,
        const ['--port', '0', '--exit-on-stdin-close'],
        environment: {'BASTIDE_SESSION_TOKEN': token},
      );
    } on ProcessException catch (error) {
      throw BackendFailure(BackendFailureKind.notFound, detail: '$error');
    }
    _process = process;
    final unexpectedExit = _unexpectedExit = Completer<int>();
    onStarted?.call(process);

    final ready = Completer<BackendConnection>();
    var sawSchemaTooNew = false;

    // Both pipes are drained for the backend's whole life: one left unread
    // fills up, and the backend then blocks on its next write.
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim() == _fatalSchemaTooNew) sawSchemaTooNew = true;
        });
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (ready.isCompleted || line.trim().isEmpty) return;
          final match = _readyLine.firstMatch(line.trim());
          final port = match == null ? null : int.parse(match.group(1)!);
          if (port == null || port == 0 || port > 65535) {
            ready.completeError(
              BackendFailure(BackendFailureKind.badHandshake, detail: line),
            );
            return;
          }
          ready.complete(
            BackendConnection(
              baseUrl: Uri.parse('http://127.0.0.1:$port/api/v1'),
              version: match!.group(2)!,
              sessionToken: token,
            ),
          );
        });

    unawaited(
      process.exitCode.then((code) {
        if (identical(_process, process)) unexpectedExit.complete(code);
        if (ready.isCompleted) return;
        final tooNew = code == exitSchemaTooNew || sawSchemaTooNew;
        ready.completeError(
          BackendFailure(
            tooNew
                ? BackendFailureKind.schemaTooNew
                : BackendFailureKind.crashed,
            exitCode: code,
          ),
        );
      }),
    );

    try {
      return await ready.future.timeout(
        readyTimeout,
        onTimeout: () => throw const BackendFailure(BackendFailureKind.timeout),
      );
    } on BackendFailure catch (failure) {
      // Never leave a half-started backend holding the database.
      if (failure.kind != BackendFailureKind.crashed &&
          failure.kind != BackendFailureKind.schemaTooNew) {
        process.kill();
      }
      rethrow;
    }
  }

  /// Stops the backend: closing stdin asks it to shut down cleanly, and it is
  /// killed if it hasn't within [grace].
  Future<void> stop({Duration grace = const Duration(seconds: 5)}) async {
    final process = _process;
    if (process == null) return;
    _process = null;
    try {
      await process.stdin.close();
    } on Object {
      // Already gone: the pipe is closed on its side.
    }
    await process.exitCode.timeout(
      grace,
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
  }
}
