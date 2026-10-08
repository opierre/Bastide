import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/auth_user.dart';

/// The session a successful register/login/reset call returns: a bearer token
/// plus the user it belongs to.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.recoveryCode,
  });

  final String token;
  final AuthUser user;

  /// The plaintext recovery code, set only by register and password reset —
  /// the one moment it exists unhashed, so it must be shown to the user now.
  final String? recoveryCode;
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

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _parseSession(json as Map<String, dynamic>);
  }

  /// Sets a new password with the recovery code. The code is spent: the
  /// returned session carries its replacement.
  Future<AuthSession> resetPassword({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final json = await _apiClient.post(
      '/auth/password-reset',
      body: {
        'email': email,
        'recovery_code': recoveryCode,
        'new_password': newPassword,
      },
    );
    return _parseSession(json as Map<String, dynamic>);
  }

  /// Replaces the signed-in user's recovery code after re-checking [password].
  Future<String> regenerateRecoveryCode({required String password}) async {
    final json =
        await _apiClient.post(
              '/auth/recovery-code',
              body: {'password': password},
            )
            as Map<String, dynamic>;
    return json['recovery_code'] as String;
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
    recoveryCode: json['recovery_code'] as String?,
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
