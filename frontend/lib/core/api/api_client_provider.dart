import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'api_client.dart';

/// The current session's bearer token, in memory. `AuthController` sets this
/// on login/logout/session-restore; the API client reads it synchronously
/// via [apiClientProvider]'s bearer hook on every request.
final authTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenProvider: () => ref.read(authTokenProvider));
});
