import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client_provider.dart';
import '../backend/backend_providers.dart';
import 'run_progress_client.dart';

/// The shared run progress socket for the running backend.
///
/// Rebuilt when the backend restarts (new port, new session token), like
/// [apiClientProvider]. Not rebuilt on login/logout: the bearer token is read
/// at each connection attempt instead, so watchers survive a token refresh.
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
    tokenProvider: () => ref.read(authTokenProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});
