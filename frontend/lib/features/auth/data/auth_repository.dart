import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/auth_user.dart';

/// The session a successful register/login call returns: a bearer token
/// plus the user it belongs to.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Calls the `/auth` endpoints and maps the wire JSON to domain models.
/// The only place in the auth feature that knows the response shape —
/// see the flutter-frontend skill's data-layer rule. `ApiClient` already
/// maps the `{error:{code,message}}` envelope to [ApiFailure], so failures
/// simply propagate.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String currency,
  }) async {
    final json = await _apiClient.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'display_name': displayName,
        'locale': locale,
        'currency': currency,
      },
    );
    return _parseSession(json as Map<String, dynamic>);
  }

  Future<AuthSession> login({required String email, required String password}) async {
    final json = await _apiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _parseSession(json as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _apiClient.post('/auth/logout');
  }

  Future<AuthUser> me() async {
    final json = await _apiClient.get('/auth/me') as Map<String, dynamic>;
    return _parseUser(json['user'] as Map<String, dynamic>);
  }

  AuthSession _parseSession(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    user: _parseUser(json['user'] as Map<String, dynamic>),
  );

  AuthUser _parseUser(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    locale: json['locale'] as String,
    currency: json['currency'] as String,
  );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
