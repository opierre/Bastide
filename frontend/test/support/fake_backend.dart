import 'dart:async';

import 'package:bastide/core/backend/backend_connection.dart';
import 'package:bastide/core/backend/backend_providers.dart';

final readyConnection = BackendConnection(
  baseUrl: Uri.parse('http://127.0.0.1:52144/api/v1'),
  version: '0.1.0',
  sessionToken: 'launch-token',
);

/// A backend that is ready at once, for tests that pump the whole app.
class ReadyBackendController extends BackendController {
  ReadyBackendController([this.connection]);

  final BackendConnection? connection;

  @override
  Future<BackendConnection> build() async => connection ?? readyConnection;
}

/// A backend the test drives: starting until [complete] or [fail], and
/// counting how often the user asked to retry.
class ScriptedBackendController extends BackendController {
  ScriptedBackendController({this.failure});

  final BackendFailure? failure;
  int retries = 0;

  @override
  Future<BackendConnection> build() {
    if (failure case final failure?) return Future.error(failure);
    return Completer<BackendConnection>().future;
  }

  @override
  void retry() => retries++;
}
