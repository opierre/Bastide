import 'package:bastide/core/app_info.dart';
import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/backend/backend_supervisor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_process.dart';

void main() {
  late List<FakeProcess> launched;
  late ProviderContainer container;

  ProviderContainer containerFor({
    String appVersion = '0.1.0',
    bool refuseMismatch = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWith((ref) async => appVersion),
        refuseMismatchedBackendProvider.overrideWithValue(refuseMismatch),
        externalBackendProvider.overrideWithValue(null),
        backendSupervisorProvider.overrideWith((ref) {
          final supervisor = BackendSupervisor(
            executable: 'bastide-backend',
            generateToken: () => 'token-${launched.length}',
            startProcess: (exe, args, {environment}) async {
              final process = FakeProcess();
              launched.add(process);
              return process;
            },
          );
          ref.onDispose(supervisor.stop);
          return supervisor;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    launched = [];
    container = containerFor();
  });

  Future<void> started() async {
    await pumpEventQueue();
    launched.last.printOut('READY 52144 0.1.0');
    await container.read(backendControllerProvider.future);
  }

  test('exposes the connection once the backend is ready', () async {
    container.listen(backendControllerProvider, (_, _) {});
    await started();

    final connection = container.read(backendControllerProvider).requireValue;
    expect(connection.baseUrl.port, 52144);
    expect(connection.sessionToken, 'token-0');
  });

  test('a crash after startup turns into a crashed failure', () async {
    container.listen(backendControllerProvider, (_, _) {});
    await started();

    launched.last.exit(1);
    await pumpEventQueue();

    final state = container.read(backendControllerProvider);
    expect(state.hasError, isTrue);
    expect((state.error! as BackendFailure).kind, BackendFailureKind.crashed);
  });

  test('retry starts a new backend with a new token', () async {
    container.listen(backendControllerProvider, (_, _) {});
    await started();
    launched.last.exit(1);
    await pumpEventQueue();

    container.read(backendControllerProvider.notifier).retry();
    await started();

    expect(launched, hasLength(2));
    expect(
      container.read(backendControllerProvider).requireValue.sessionToken,
      'token-1',
    );
  });

  group('version check', () {
    Future<AsyncValue<BackendConnection>> startWith(
      ProviderContainer target,
    ) async {
      target.listen(backendControllerProvider, (_, _) {});
      await pumpEventQueue();
      launched.last.printOut('READY 52144 0.1.0');
      await pumpEventQueue();
      return target.read(backendControllerProvider);
    }

    test('a matching version passes', () async {
      final state = await startWith(container);

      expect(state.requireValue.mismatchedAppVersion, isNull);
    });

    test('the app build number is not part of the version', () async {
      launched = [];
      final state = await startWith(containerFor(appVersion: '0.1.0+7'));

      expect(state.hasValue, isTrue);
    });

    test('release: a mismatch is refused and the backend stopped', () async {
      launched = [];
      final state = await startWith(containerFor(appVersion: '0.2.0'));

      final failure = state.error! as BackendFailure;
      expect(failure.kind, BackendFailureKind.versionMismatch);
      expect(failure.appVersion, '0.2.0');
      expect(failure.backendVersion, '0.1.0');
      expect(launched.last.stdinClosed, isTrue);
    });

    test('debug: a mismatch is let through, flagged', () async {
      launched = [];
      final state = await startWith(
        containerFor(appVersion: '0.2.0', refuseMismatch: false),
      );

      expect(state.requireValue.mismatchedAppVersion, '0.2.0');
      expect(launched.last.stdinClosed, isFalse);
    });
  });
}
