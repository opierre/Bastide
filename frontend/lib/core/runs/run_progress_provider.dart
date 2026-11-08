import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client_provider.dart';
import '../backend/backend_providers.dart';
import 'run_progress_client.dart';
import 'run_socket.dart';

/// How the run progress client opens its socket. Tests override it with a
/// fake that plays the server.
final runSocketConnectorProvider = Provider<RunSocketConnector>(
  (ref) => connectIoRunSocket,
);

/// The shared run progress socket for the running backend and the current
/// session.
///
/// Rebuilt when the backend restarts (new port, new session token), like
/// [apiClientProvider], and also whenever the bearer token changes — login,
/// logout, session restore. The old client is disposed on the spot: its
/// socket closes, its watchers' streams end and its cache of run events is
/// dropped, so a logged-out socket never lingers nor reconnects, and nothing
/// heard in one session shows up in the next. Watchers belong to panels that
/// a logout leaves anyway; one that is still listening simply sees its stream
/// end.
///
/// Tests override it with a fake or a mocktail mock whose `watch` returns a
/// stream they drive.
final runProgressClientProvider = Provider<RunProgressClient>((ref) {
  final connection = ref.watch(backendControllerProvider).value;
  if (connection == null) {
    throw StateError(
      'The run progress client was read before the backend was ready.',
    );
  }
  final client = RunProgressClient(
    baseUrl: connection.baseUrl,
    sessionToken: connection.sessionToken,
    bearerToken: ref.watch(authTokenProvider),
    connector: ref.watch(runSocketConnectorProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});
