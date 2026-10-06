import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session token outside app state, so it survives restarts.
/// Abstracted for testability — `AuthController` depends on this interface,
/// never on `flutter_secure_storage` directly.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// OS-backed secure storage (Keychain / Credential Manager / libsecret).
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _tokenKey);
}
