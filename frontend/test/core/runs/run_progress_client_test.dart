import 'dart:async';

import 'package:bastide/core/runs/run_event.dart';
import 'package:bastide/core/runs/run_progress_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_run_socket.dart';

void main() {
  late List<FakeRunSocket> sockets;
  late List<Map<String, String>> headersSeen;
  late List<Uri> urlsSeen;
  late bool refuse;
  late RunProgressClient client;

  setUp(() {
    sockets = [];
    headersSeen = [];
    urlsSeen = [];
    refuse = false;
    client = RunProgressClient(
      baseUrl: Uri.parse('http://127.0.0.1:52144/api/v1'),
      sessionToken: 'session-abc',
      bearerToken: 'bearer-xyz',
      backoff: (_) => Duration.zero,
      connector: (url, headers) async {
        urlsSeen.add(url);
        headersSeen.add(headers);
        if (refuse) throw Exception('connection refused');
        final socket = FakeRunSocket();
        sockets.add(socket);
        return socket;
      },
    );
    addTearDown(client.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('connects lazily with the REST auth headers', () async {
    expect(urlsSeen, isEmpty);

    final sub = client.watch('run-1').listen((_) {});
    await settle();

    expect(urlsSeen.single.toString(), 'ws://127.0.0.1:52144/api/v1/runs/ws');
    expect(headersSeen.single, {
      'X-Bastide-Session': 'session-abc',
      'Authorization': 'Bearer bearer-xyz',
    });
    await sub.cancel();
  });

  test('delivers the snapshot then only the watched run events', () async {
    final updates = <RunUpdate>[];
    final sub = client.watch('run-1').listen(updates.add);
    await settle();

    sockets.single.sendSnapshot([
      runEventJson(event: 'started', done: 0),
      runEventJson(runId: 'run-other', event: 'started'),
    ]);
    sockets.single.sendEvent(runEventJson(runId: 'run-other', done: 5));
    sockets.single.sendEvent(
      runEventJson(done: 40, counts: {'assigned': 30, 'deferred': 10}),
    );
    await settle();

    expect(updates, hasLength(2));
    expect((updates[0] as RunResync).latest?.type, RunEventType.started);
    final event = (updates[1] as RunEventUpdate).event;
    expect(event.done, 40);
    expect(event.counts, {'assigned': 30, 'deferred': 10});
    await sub.cancel();
  });

  test('a snapshot without the run resyncs with null', () async {
    final updates = <RunUpdate>[];
    final sub = client.watch('run-1').listen(updates.add);
    await settle();

    sockets.single.sendSnapshot([]);
    await settle();

    expect((updates.single as RunResync).latest, isNull);
    await sub.cancel();
  });

  test('tolerates unknown kinds, events and message types', () async {
    final updates = <RunUpdate>[];
    final sub = client.watch('run-9').listen(updates.add);
    await settle();

    sockets.single
      ..sendSnapshot([])
      ..sendJson({'type': 'something_new'})
      ..sendEvent(runEventJson(runId: 'run-9', event: 'paused'))
      ..sendEvent(
        runEventJson(runId: 'run-9', kind: 'rule_pack_import', done: 3),
      );
    await settle();

    expect(updates, hasLength(2));
    expect((updates[1] as RunEventUpdate).event.kind, 'rule_pack_import');
    await sub.cancel();
  });

  test('a late watcher hears a run that already ended', () async {
    final first = client.watch('run-1').listen((_) {});
    await settle();
    sockets.single
      ..sendSnapshot([])
      ..sendEvent(runEventJson(event: 'finished', done: 200));
    await settle();

    final updates = <RunUpdate>[];
    final second = client.watch('run-1').listen(updates.add);
    await settle();

    expect((updates.single as RunResync).latest?.type, RunEventType.finished);
    await first.cancel();
    await second.cancel();
  });

  test('reconnects after a drop and resyncs from the new snapshot', () async {
    final updates = <RunUpdate>[];
    final sub = client.watch('run-1').listen(updates.add);
    await settle();
    sockets[0].sendSnapshot([runEventJson(event: 'started')]);
    await settle();

    await sockets[0].serverClose();
    await settle();
    await settle();

    expect(sockets, hasLength(2));
    expect(updates[1], isA<RunConnectionLost>());

    sockets[1].sendSnapshot([runEventJson(done: 120)]);
    await settle();
    expect((updates.last as RunResync).latest?.done, 120);
    await sub.cancel();
  });

  test('retries a failed connection with backoff', () async {
    refuse = true;
    final updates = <RunUpdate>[];
    final sub = client.watch('run-1').listen(updates.add);
    await settle();
    expect(updates.whereType<RunConnectionLost>(), isNotEmpty);

    refuse = false;
    for (var i = 0; i < 5 && sockets.isEmpty; i++) {
      await settle();
    }
    expect(sockets, hasLength(1));
    await sub.cancel();
  });

  test('stops retrying when the bearer token is refused', () async {
    final updates = <RunUpdate>[];
    final sub = client.watch('run-1').listen(updates.add);
    await settle();

    await sockets.single.serverClose(4401);
    await settle();
    await settle();

    expect((updates.single as RunConnectionLost).unauthenticated, isTrue);
    expect(sockets, hasLength(1));
    await sub.cancel();
  });

  test('a refused token stays refused for later watchers', () async {
    final first = client.watch('run-1').listen((_) {});
    await settle();
    await sockets.single.serverClose(4401);
    await settle();
    await first.cancel();

    final updates = <RunUpdate>[];
    final second = client.watch('run-2').listen(updates.add);
    await settle();
    await settle();

    expect((updates.single as RunConnectionLost).unauthenticated, isTrue);
    expect(sockets, hasLength(1));
    await second.cancel();
  });

  test('never connects without a bearer token', () async {
    final signedOut = RunProgressClient(
      baseUrl: Uri.parse('http://127.0.0.1:52144/api/v1'),
      sessionToken: 'session-abc',
      backoff: (_) => Duration.zero,
      connector: (url, headers) async {
        urlsSeen.add(url);
        return FakeRunSocket();
      },
    );
    addTearDown(signedOut.dispose);

    final updates = <RunUpdate>[];
    final sub = signedOut.watch('run-1').listen(updates.add);
    await settle();
    await settle();

    expect((updates.single as RunConnectionLost).unauthenticated, isTrue);
    expect(urlsSeen, isEmpty);
    await sub.cancel();
  });

  test('closes the socket when the last watcher leaves', () async {
    final a = client.watch('run-1').listen((_) {});
    final b = client.watch('run-2').listen((_) {});
    await settle();

    await a.cancel();
    expect(sockets.single.closedByClient, isFalse);
    await b.cancel();
    expect(sockets.single.closedByClient, isTrue);
  });

  test('defaults to an exponential backoff capped at 30 s', () {
    expect(defaultRunSocketBackoff(0), const Duration(seconds: 1));
    expect(defaultRunSocketBackoff(3), const Duration(seconds: 8));
    expect(defaultRunSocketBackoff(12), const Duration(seconds: 30));
  });

  test('dispose ends every watcher stream', () async {
    final done = Completer<void>();
    client.watch('run-1').listen((_) {}, onDone: done.complete);
    await settle();

    await client.dispose();

    await done.future.timeout(const Duration(seconds: 1));
  });
}
