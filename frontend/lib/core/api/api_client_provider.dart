import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../backend/backend_providers.dart';
import 'api_client.dart';

/// The current session's bearer token, in memory. `AuthController` sets this
/// on login/logout/session-restore; the API client reads it synchronously
/// via [apiClientProvider]'s bearer hook on every request.
final authTokenProvider = StateProvider<String?>((ref) => null);

/// The client for the running backend. Rebuilt when the backend restarts,
/// since a new launch has a new port and a new session token.
///
/// Read only once the backend is ready: the app shows its startup screen
/// until then, so nothing that calls the API is built before it.
final apiClientProvider = Provider<ApiClient>((ref) {
  final connection = ref.watch(backendControllerProvider).value;
  if (connection == null) {
    throw StateError('The API client was read before the backend was ready.');
  }
  return ApiClient(
    baseUrl: connection.baseUrl,
    sessionToken: connection.sessionToken,
    tokenProvider: () => ref.read(authTokenProvider),
  );
});
