import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_user.dart';

/// The signed-in user, re-exposed as a core-level cross-cutting concern (the
/// same reasoning as `authTokenProvider` in `api_client_provider.dart`) so
/// non-auth features can read profile fields like `currency` without
/// reaching into the auth feature's internals — see the architecture
/// skill's "cross-feature reach-in is forbidden" rule.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).value;
});
