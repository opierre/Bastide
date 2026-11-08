import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../backend/backend_connection.dart';
import 'run_event.dart';
import 'run_socket.dart';

/// The close code the backend uses for a missing or rejected bearer token
/// (`app/core/websocket.py`).
const runSocketUnauthenticatedCode = 4401;

/// How long a connection attempt may take before it counts as failed.
const runSocketConnectTimeout = Duration(seconds: 10);

/// Waits 1 s, 2 s, 4 s… between attempts, capped at 30 s: quick enough to pick
/// a restarted sidecar straight back up, slow enough not to spin against one
/// that is gone.
Duration defaultRunSocketBackoff(int attempt) {
  final seconds = 1 << (attempt.clamp(0, 5));
  return Duration(seconds: seconds > 30 ? 30 : seconds);
}

/// The app's one connection to `GET /runs/ws`, shared by every feature that
/// follows a background run (categorization, rule pack import, …).
///
/// A feature calls [watch] with a run id and listens. The socket opens with
/// the first watcher and closes with the last, so nothing stays connected
/// while no run is on screen. It reconnects on its own with backoff; every
/// (re)connection starts with the server's snapshot, which each watcher gets
/// as a [RunResync] — the moment to catch up on whatever was missed.
class RunProgressClient {
  RunProgressClient({
    required Uri baseUrl,
    this.sessionToken,
    this.tokenProvider,
    RunSocketConnector? connector,
    Duration Function(int attempt)? backoff,
  }) : url = _socketUrl(baseUrl),
       _connector = connector ?? connectIoRunSocket,
       _backoff = backoff ?? defaultRunSocketBackoff;

  /// `ws://127.0.0.1:<port>/api/v1/runs/ws`, from the REST API root.
  final Uri url;

  /// Sent as `X-Bastide-Session`, as on every REST request.
  final String? sessionToken;

  /// The current bearer token, read at every connection attempt so a socket
  /// opened after a login carries the new one.
  final String? Function()? tokenProvider;

  final RunSocketConnector _connector;
  final Duration Function(int attempt) _backoff;

  final List<_Watcher> _watchers = [];

  /// Latest event of each run active on the bus, as of the last snapshot plus
  /// every event since.
  final Map<String, RunEvent> _active = {};

  /// Terminal events heard on this client, so a watcher that subscribes just
  /// after its run ended still learns how. Bounded; oldest dropped first.
  final LinkedHashMap<String, RunEvent> _ended = LinkedHashMap();
  static const _endedCapacity = 32;

  RunSocket? _socket;
  StreamSubscription<Object?>? _socketSubscription;
  Timer? _retry;
  bool _connecting = false;

  /// The server has sent this connection's snapshot.
  bool _synced = false;

  /// The backend refused the bearer token; retrying with the same one is
  /// pointless until a new watcher (likely after a new login) asks again.
  bool _halted = false;
  int _attempt = 0;
  bool _disposed = false;

  /// Follows one run. Emits a [RunResync] on every (re)connection — right away
  /// when the socket is already up — then a [RunEventUpdate] per event of that
  /// run, and a [RunConnectionLost] whenever the socket fails or drops.
  ///
  /// The stream never closes on its own (except when the client is disposed):
  /// cancel the subscription once the run is over.
  Stream<RunUpdate> watch(String runId) {
    late final _Watcher watcher;
    final controller = StreamController<RunUpdate>(
      onListen: () {
        if (_disposed) return;
        _watchers.add(watcher);
        if (_halted) {
          _halted = false;
          _attempt = 0;
        }
        if (_synced) watcher.add(RunResync(_known(runId)));
        _ensureConnected();
      },
      onCancel: () {
        _watchers.remove(watcher);
        if (_watchers.isEmpty) _disconnect();
      },
    );
    watcher = _Watcher(runId, controller);
    return controller.stream;
  }

  /// Closes the socket and ends every watcher's stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final watchers = List.of(_watchers);
    _watchers.clear();
    _disconnect();
    for (final watcher in watchers) {
      await watcher.controller.close();
    }
  }

  RunEvent? _known(String runId) => _active[runId] ?? _ended[runId];

  Map<String, String> _headers() {
    final token = tokenProvider?.call();
    return {
      sessionTokenHeader: ?sessionToken,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _ensureConnected() async {
    if (_disposed ||
        _halted ||
        _socket != null ||
        _connecting ||
        _retry != null ||
        _watchers.isEmpty) {
      return;
    }
    _connecting = true;
    final RunSocket socket;
    try {
      socket = await _connector(
        url,
        _headers(),
      ).timeout(runSocketConnectTimeout);
    } catch (_) {
      _connecting = false;
      _onFailure();
      return;
    }
    _connecting = false;
    if (_disposed || _watchers.isEmpty) {
      unawaited(socket.close());
      return;
    }
    _socket = socket;
    _socketSubscription = socket.messages.listen(
      _onMessage,
      // A transport error is followed by `onDone`, which does the recovery.
      onError: (Object _) {},
      onDone: () => _onClosed(socket),
    );
  }

  void _onMessage(Object? data) {
    if (data is! String) return;
    final Object? message;
    try {
      message = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (message is! Map<String, dynamic>) return;
    switch (message['type']) {
      case 'snapshot':
        final runs = message['runs'];
        _active
          ..clear()
          ..addEntries([
            if (runs is List)
              for (final raw in runs)
                if (RunEvent.tryParse(raw) case final event?)
                  MapEntry(event.runId, event),
          ]);
        _synced = true;
        _attempt = 0;
        for (final watcher in List.of(_watchers)) {
          watcher.add(RunResync(_known(watcher.runId)));
        }
      case 'event':
        final event = RunEvent.tryParse(message['event']);
        if (event == null) return;
        _remember(event);
        for (final watcher in List.of(_watchers)) {
          if (watcher.runId == event.runId) watcher.add(RunEventUpdate(event));
        }
      // Any other message type is from a newer backend; skip it.
    }
  }

  void _remember(RunEvent event) {
    if (event.type.isTerminal) {
      _active.remove(event.runId);
      _ended
        ..remove(event.runId)
        ..[event.runId] = event;
      while (_ended.length > _endedCapacity) {
        _ended.remove(_ended.keys.first);
      }
    } else {
      _active[event.runId] = event;
    }
  }

  void _onClosed(RunSocket socket) {
    if (!identical(socket, _socket)) return;
    _socket = null;
    _socketSubscription = null;
    _synced = false;
    if (_disposed || _watchers.isEmpty) return;
    if (socket.closeCode == runSocketUnauthenticatedCode) {
      _halted = true;
      _broadcast(const RunConnectionLost(unauthenticated: true));
      return;
    }
    _onFailure();
  }

  void _onFailure() {
    if (_disposed || _watchers.isEmpty) return;
    _broadcast(const RunConnectionLost());
    _retry = Timer(_backoff(_attempt++), () {
      _retry = null;
      unawaited(_ensureConnected());
    });
  }

  void _broadcast(RunUpdate update) {
    for (final watcher in List.of(_watchers)) {
      watcher.add(update);
    }
  }

  void _disconnect() {
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
    _synced = false;
    final socket = _socket;
    _socket = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    if (socket != null) unawaited(socket.close());
  }

  static Uri _socketUrl(Uri baseUrl) => baseUrl.replace(
    scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
    path: '${baseUrl.path}/runs/ws',
  );
}

class _Watcher {
  _Watcher(this.runId, this.controller);

  final String runId;
  final StreamController<RunUpdate> controller;

  void add(RunUpdate update) {
    if (!controller.isClosed) controller.add(update);
  }
}
