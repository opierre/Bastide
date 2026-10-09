import 'dart:io';
import 'dart:math';

import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_locator.dart';
import 'package:bastide/core/backend/backend_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_process.dart';

class _Launch {
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
}

void main() {
  late FakeProcess process;
  late _Launch launch;

  BackendSupervisor supervisor({
    String? executable = '/app/backend/bastide-backend',
    Duration readyTimeout = const Duration(seconds: 5),
  }) {
    return BackendSupervisor(
      executable: executable,
      generateToken: () => 'launch-token',
      readyTimeout: readyTimeout,
      startProcess: (exe, args, {environment}) async {
        launch
          ..executable = exe
          ..arguments = args
          ..environment = environment;
        return process;
      },
    );
  }

  Future<BackendFailure> failureOf(Future<Object?> future) async {
    try {
      await future;
    } on BackendFailure catch (failure) {
      return failure;
    }
    fail('expected a BackendFailure');
  }

  setUp(() {
    process = FakeProcess();
    launch = _Launch();
  });

  test('ready: parses the handshake into a connection', () async {
    final starting = supervisor().start();
    process.printOut('READY 52144 0.1.0');

    final connection = await starting;
    expect(connection.baseUrl, Uri.parse('http://127.0.0.1:52144/api/v1'));
    expect(connection.version, '0.1.0');
    expect(connection.sessionToken, 'launch-token');
  });

  test('passes the token in the environment, never in argv', () async {
    final starting = supervisor().start();
    process.printOut('READY 52144 0.1.0');
    await starting;

    expect(launch.executable, '/app/backend/bastide-backend');
    expect(launch.arguments, ['--port', '0', '--exit-on-stdin-close']);
    expect(launch.environment, {'BASTIDE_SESSION_TOKEN': 'launch-token'});
    expect(launch.arguments!.join(' '), isNot(contains('launch-token')));
  });

  test('timeout: kills a backend that never answers', () async {
    final failure = await failureOf(
      supervisor(readyTimeout: const Duration(milliseconds: 20)).start(),
    );

    expect(failure.kind, BackendFailureKind.timeout);
    expect(process.killed, isTrue);
  });

  test('crash: an exit before the handshake carries the exit code', () async {
    final starting = supervisor().start();
    process.printErr('Traceback (most recent call last):');
    process.exit(1);

    final failure = await failureOf(starting);
    expect(failure.kind, BackendFailureKind.crashed);
    expect(failure.exitCode, 1);
  });

  test('schema too new: exit code 10 is told apart from a crash', () async {
    final starting = supervisor().start();
    process.printErr('FATAL DATABASE_SCHEMA_TOO_NEW');
    process.exit(exitSchemaTooNew);

    final failure = await failureOf(starting);
    expect(failure.kind, BackendFailureKind.schemaTooNew);
  });

  test('bad line: anything but the handshake on stdout fails', () async {
    final starting = supervisor().start();
    process.printOut('Hello from uvicorn');

    final failure = await failureOf(starting);
    expect(failure.kind, BackendFailureKind.badHandshake);
    expect(failure.detail, 'Hello from uvicorn');
    expect(process.killed, isTrue);
  });

  test('bad line: a READY line without a usable port fails', () async {
    final starting = supervisor().start();
    process.printOut('READY 0 0.1.0');

    expect((await failureOf(starting)).kind, BackendFailureKind.badHandshake);
  });

  test('not found: no executable means no process', () async {
    final failure = await failureOf(supervisor(executable: null).start());

    expect(failure.kind, BackendFailureKind.notFound);
    expect(launch.executable, isNull);
  });

  test('not found: a process that cannot be spawned', () async {
    final starter = BackendSupervisor(
      executable: '/missing',
      startProcess: (exe, args, {environment}) =>
          throw const ProcessException('/missing', [], 'No such file'),
    );

    expect(
      (await failureOf(starter.start())).kind,
      BackendFailureKind.notFound,
    );
  });

  test('a crash after the handshake is reported as unexpected', () async {
    final backend = supervisor();
    final starting = backend.start();
    process.printOut('READY 52144 0.1.0');
    await starting;

    process.exit(3);
    expect(await backend.unexpectedExit, 3);
  });

  test('stop closes stdin and is not an unexpected exit', () async {
    final backend = supervisor();
    final starting = backend.start();
    process.printOut('READY 52144 0.1.0');
    await starting;

    var unexpected = false;
    backend.unexpectedExit.then((_) => unexpected = true);
    await backend.stop();
    await pumpEventQueue();

    expect(process.stdinClosed, isTrue);
    expect(process.killed, isFalse);
    expect(unexpected, isFalse);
  });

  test('stop kills a backend that ignores stdin closing', () async {
    process = FakeProcess(exitOnStdinClose: false);
    final backend = supervisor();
    final starting = backend.start();
    process.printOut('READY 52144 0.1.0');
    await starting;

    await backend.stop(grace: const Duration(milliseconds: 20));
    expect(process.killed, isTrue);
  });

  test('session tokens are long and differ per launch', () {
    final first = generateSessionToken(Random(1));
    final second = generateSessionToken(Random(2));

    expect(first.length, greaterThanOrEqualTo(43));
    expect(first, isNot(second));
    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });

  group('locateBackendExecutable', () {
    test('Windows: backend folder next to the executable', () {
      final found = locateBackendExecutable(
        appExecutable: r'C:\Apps\Bastide\bastide.exe',
        operatingSystem: 'windows',
        exists: (_) => true,
      );
      expect(found, endsWith(r'Bastide\backend\bastide-backend.exe'));
    });

    test('macOS: Contents/Resources/backend', () {
      final found = locateBackendExecutable(
        appExecutable: '/Applications/Bastide.app/Contents/MacOS/Bastide',
        operatingSystem: 'macos',
        exists: (_) => true,
      );
      expect(
        found,
        '/Applications/Bastide.app/Contents/Resources/backend/bastide-backend',
      );
    });

    test('none when the packaged backend is missing', () {
      final found = locateBackendExecutable(
        appExecutable: '/opt/bastide/bastide',
        operatingSystem: 'linux',
        exists: (_) => false,
      );
      expect(found, isNull);
    });

    test('a developer override wins', () {
      final found = locateBackendExecutable(
        appExecutable: '/opt/bastide/bastide',
        operatingSystem: 'linux',
        exists: (_) => false,
        override: '/src/dist/bastide-backend/bastide-backend',
      );
      expect(found, '/src/dist/bastide-backend/bastide-backend');
    });
  });
}
