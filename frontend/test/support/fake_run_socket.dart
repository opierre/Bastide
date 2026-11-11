import 'dart:async';
import 'dart:convert';

import 'package:bastide/core/runs/run_socket.dart';

/// An in-memory [RunSocket]: the test plays the server.
class FakeRunSocket implements RunSocket {
  final _frames = StreamController<Object?>();

  @override
  int? closeCode;

  bool closedByClient = false;

  @override
  Stream<Object?> get messages => _frames.stream;

  void sendJson(Object message) => _frames.add(jsonEncode(message));

  void sendSnapshot(List<Map<String, dynamic>> runs) =>
      sendJson({'type': 'snapshot', 'runs': runs});

  void sendEvent(Map<String, dynamic> event) =>
      sendJson({'type': 'event', 'event': event});

  /// The server ends the connection, optionally with a close code.
  Future<void> serverClose([int? code]) {
    closeCode = code;
    return _frames.close();
  }

  @override
  Future<void> close() async {
    closedByClient = true;
    if (!_frames.isClosed) await _frames.close();
  }
}

/// A run event on the wire, with invented values.
Map<String, dynamic> runEventJson({
  String runId = 'run-1',
  String kind = 'categorization',
  String event = 'progress',
  int done = 0,
  int total = 200,
  Map<String, int> counts = const {},
  String? errorMessage,
}) => {
  'run_id': runId,
  'kind': kind,
  'event': event,
  'done': done,
  'total': total,
  'counts': counts,
  'error_message': errorMessage,
  'occurred_at': '2026-05-14T10:00:00Z',
};
