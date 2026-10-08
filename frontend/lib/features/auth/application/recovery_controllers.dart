import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// The « Mot de passe oublié » form's submission. Separate from
/// [AuthController] so a failed reset errors this form alone, rather than
/// putting the whole session into an error state the login screen would show.
class PasswordResetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: email,
            recoveryCode: recoveryCode,
            newPassword: newPassword,
          );
      await ref.read(authControllerProvider.notifier).startSession(session);
    });
  }
}

/// Auto-disposed so a stale error doesn't greet the next visit to the form.
final passwordResetControllerProvider =
    AsyncNotifierProvider.autoDispose<PasswordResetController, void>(
      PasswordResetController.new,
    );

/// Generates a replacement recovery code from Settings › Profil. Data is the
/// new plaintext code, `null` until one has been generated.
class RecoveryCodeRegenerateController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> regenerate({required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .regenerateRecoveryCode(password: password),
    );
  }
}

/// Auto-disposed with the modal, so the plaintext code is dropped from memory
/// once the user closes it.
final recoveryCodeRegenerateControllerProvider =
    AsyncNotifierProvider.autoDispose<
      RecoveryCodeRegenerateController,
      String?
    >(RecoveryCodeRegenerateController.new);
