import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client_provider.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Session state: `null` = signed out, otherwise the current user.
/// `build()` restores a session from a stored token on app launch;
/// `startSession` (after a login, a registration or a password reset) and
/// `logout` drive the rest of the lifecycle. The router watches this to gate
/// navigation (see `core/router/app_router.dart`).
///
/// It never holds a form's failure: a rejected login or registration leaves
/// the user signed out, and the error belongs to that form's own controller
/// (`auth_form_controllers.dart`), so it cannot leak onto another screen.
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

  /// Adopts a session a form obtained — login, registration or password
  /// reset — so the router treats the user as signed in from here on.
  Future<void> startSession(AuthSession session) async {
    await _persistSession(session);
    state = AsyncValue.data(session.user);
  }

  /// Swaps in the signed-in user's updated profile, so everything watching
  /// the session (the top bar's user pill) shows the change at once.
  void replaceUser(AuthUser user) => state = AsyncValue.data(user);

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
    // Set before the session state flips to signed-in, so the router's first
    // redirect already sees the code waiting and shows it before the dashboard.
    if (session.recoveryCode case final code?) {
      ref.read(pendingRecoveryCodeProvider.notifier).show(code);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

/// A recovery code the user hasn't acknowledged yet. While set, the router
/// keeps a signed-in user on the recovery-code screen: the code is never stored
/// unhashed, so leaving that screen without noting it loses it.
class PendingRecoveryCode extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String code) => state = code;

  void acknowledge() => state = null;
}

final pendingRecoveryCodeProvider =
    NotifierProvider<PendingRecoveryCode, String?>(PendingRecoveryCode.new);
