import 'dart:async';

import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/backend/backend_providers.dart';
import 'package:bastide/core/runs/run_event.dart';
import 'package:bastide/core/runs/run_progress_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_run_socket.dart';

void main() {
  late List<FakeRunSocket> sockets;
  late List<Map<String, String>> headersSeen;
  late ProviderContainer container;

  setUp(() async {
    sockets = [];
    headersSeen = [];
    container = ProviderContainer(
      overrides: [
        backendControllerProvider.overrideWith(ReadyBackendController.new),
        runSocketConnectorProvider.overrideWithValue((url, headers) async {
          headersSeen.add(headers);
          final socket = FakeRunSocket();
          sockets.add(socket);
          return socket;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(backendControllerProvider.future);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void signIn(String? token) =>
      container.read(authTokenProvider.notifier).state = token;

  test('logout closes the socket and ends the watchers', () async {
    signIn('bearer-old');
    final done = Completer<void>();
    final sub = container
        .read(runProgressClientProvider)
        .watch('run-1')
        .listen((_) {}, onDone: done.complete);
    await settle();
    expect(sockets.single.closedByClient, isFalse);

    signIn(null);

    expect(sockets.single.closedByClient, isTrue);
    await done.future.timeout(const Duration(seconds: 1));
    await sub.cancel();
  });

  test('no reconnect after logout, even on a late 4401', () async {
    signIn('bearer-old');
    final sub = container
        .read(runProgressClientProvider)
        .watch('run-1')
        .listen((_) {});
    await settle();

    signIn(null);
    await sockets.single.serverClose(4401);
    await settle();
    await settle();

    // A watcher while signed out gets told so and opens nothing.
    final updates = <RunUpdate>[];
    final signedOut = container
        .read(runProgressClientProvider)
        .watch('run-1')
        .listen(updates.add);
    await settle();
    await settle();

    expect(sockets, hasLength(1));
    expect((updates.single as RunConnectionLost).unauthenticated, isTrue);
    await sub.cancel();
    await signedOut.cancel();
  });

  test('a new login gets a fresh client, token and cache', () async {
    signIn('bearer-old');
    final oldClient = container.read(runProgressClientProvider);
    final first = oldClient.watch('run-1').listen((_) {});
    await settle();
    sockets.single
      ..sendSnapshot([])
      ..sendEvent(runEventJson(event: 'finished', done: 200));
    await settle();

    signIn(null);
    signIn('bearer-new');
    final newClient = container.read(runProgressClientProvider);
    expect(identical(newClient, oldClient), isFalse);

    final updates = <RunUpdate>[];
    final second = newClient.watch('run-1').listen(updates.add);
    await settle();
    expect(headersSeen.last['Authorization'], 'Bearer bearer-new');

    // The run that ended in the old session is not remembered here.
    sockets.last.sendSnapshot([]);
    await settle();
    expect((updates.single as RunResync).latest, isNull);
    await first.cancel();
    await second.cancel();
  });
}
