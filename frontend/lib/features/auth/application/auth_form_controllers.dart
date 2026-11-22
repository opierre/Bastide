import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// The « Connexion » form's submission. Separate from [AuthController] so a
/// rejected pair errors this form alone: kept on the session, the error
/// followed the user to « Inscription » and showed there (#319).
class LoginController extends AsyncNotifier<void> {
  @override
  // Synchronous, so the form opens idle rather than loading for a frame.
  FutureOr<void> build() {}

  /// Signs in with [identifier]: the email or the display name.
  Future<void> submit({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);
      await ref.read(authControllerProvider.notifier).startSession(session);
    });
  }
}

/// Auto-disposed so a stale error doesn't greet the next visit to the form.
final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
      LoginController.new,
    );

/// The fields of « Inscription » an edit can come from.
enum RegisterField { displayName, email, password }

/// The « Inscription » form's submission. Separate from [AuthController] so
/// only a registration failure ever shows on this form.
class RegisterController extends AsyncNotifier<void> {
  @override
  // Synchronous, so the form opens idle rather than loading for a frame.
  FutureOr<void> build() {}

  Future<void> submit({
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
      await ref.read(authControllerProvider.notifier).startSession(session);
    });
  }

  /// Drops the error the user is now correcting. A taken name or e-mail is
  /// that field's own error, so only editing that field clears it; any other
  /// failure has no field and clears on the first edit.
  void fieldEdited(RegisterField field) {
    if (!state.hasError) return;
    final owner = switch (state.error) {
      ApiFailure(code: 'DISPLAY_NAME_TAKEN') => RegisterField.displayName,
      ApiFailure(code: 'EMAIL_TAKEN') => RegisterField.email,
      _ => null,
    };
    if (owner == null || owner == field) state = const AsyncValue.data(null);
  }
}

/// Auto-disposed so a stale error doesn't greet the next visit to the form.
final registerControllerProvider =
    AsyncNotifierProvider.autoDispose<RegisterController, void>(
      RegisterController.new,
    );
