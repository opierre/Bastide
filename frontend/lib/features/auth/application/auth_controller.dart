import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client_provider.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Session state: `null` = signed out, otherwise the current user.
/// `build()` restores a session from a stored token on app launch; `login`,
/// `register`, and `logout` drive the rest of the lifecycle. The router
/// watches this to gate navigation (see `core/router/app_router.dart`).
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final token = await ref.watch(tokenStoreProvider).read();
    if (token == null) return null;

    ref.read(authTokenProvider.notifier).state = token;
    try {
      return await ref.read(authRepositoryProvider).me();
    } catch (_) {
      // Stored token is stale/invalid — fall back to signed-out rather than
      // surface an error on launch.
      await ref.read(tokenStoreProvider).delete();
      ref.read(authTokenProvider.notifier).state = null;
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await _persistSession(session);
      return session.user;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String currency,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .register(
            email: email,
            password: password,
            displayName: displayName,
            locale: locale,
            currency: currency,
          );
      await _persistSession(session);
      return session.user;
    });
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Best-effort server-side invalidation; clear local state regardless.
    }
    await ref.read(tokenStoreProvider).delete();
    ref.read(authTokenProvider.notifier).state = null;
    state = const AsyncValue.data(null);
  }

  Future<void> _persistSession(AuthSession session) async {
    await ref.read(tokenStoreProvider).write(session.token);
    ref.read(authTokenProvider.notifier).state = session.token;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);
