import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/backend/backend_supervisor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_process.dart';

void main() {
  late List<FakeProcess> launched;
  late ProviderContainer container;

  setUp(() {
    launched = [];
    container = ProviderContainer(
      overrides: [
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
}
