import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/availability.dart';
import '../domain/display_name.dart';
import '../domain/email_address.dart';
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

/// How long « Inscription » waits after the last keystroke before asking the
/// sidecar whether the e-mail or the username is free: one request per pause,
/// not one per letter.
const registerAvailabilityDebounce = Duration(milliseconds: 400);

/// Whether the e-mail and the username typed on « Inscription » are free.
@immutable
class RegisterAvailability {
  const RegisterAvailability({
    this.email = Availability.unknown,
    this.displayName = Availability.unknown,
  });

  final Availability email;
  final Availability displayName;

  /// Whether a field still blocks the submission: taken, or not yet answered.
  bool get blocksSubmit => [email, displayName].any(
    (value) => value == Availability.taken || value == Availability.checking,
  );

  RegisterAvailability _with(RegisterField field, Availability value) =>
      switch (field) {
        RegisterField.email => RegisterAvailability(
          email: value,
          displayName: displayName,
        ),
        RegisterField.displayName => RegisterAvailability(
          email: email,
          displayName: value,
        ),
        RegisterField.password => this,
      };

  @override
  bool operator ==(Object other) =>
      other is RegisterAvailability &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(email, displayName);
}

/// Checks, while the user types, that the e-mail and the username are still
/// free (#320), so a taken one shows on its field before any submit and both
/// can show at once. Each field has its own debounce, and an answer for a
/// value the user has since changed is dropped.
class RegisterAvailabilityController extends Notifier<RegisterAvailability> {
  final _timers = <RegisterField, Timer>{};
  final _requestIds = <RegisterField, int>{};

  @override
  RegisterAvailability build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    return const RegisterAvailability();
  }

  void emailChanged(String email) =>
      _schedule(RegisterField.email, email.trim(), isPlausibleEmail);

  void displayNameChanged(String displayName) => _schedule(
    RegisterField.displayName,
    normalizeDisplayName(displayName),
    isValidDisplayName,
  );

  void _schedule(
    RegisterField field,
    String value,
    bool Function(String) isWellFormed,
  ) {
    _timers.remove(field)?.cancel();
    final requestId = (_requestIds[field] ?? 0) + 1;
    _requestIds[field] = requestId;
    // A malformed value is the form's own error and belongs to no one.
    if (!isWellFormed(value)) {
      state = state._with(field, Availability.unknown);
      return;
    }
    state = state._with(field, Availability.checking);
    _timers[field] = Timer(registerAvailabilityDebounce, () {
      unawaited(_check(field, value, requestId));
    });
  }

  Future<void> _check(RegisterField field, String value, int requestId) async {
    final isEmail = field == RegisterField.email;
    Availability result;
    try {
      final answer = await ref
          .read(authRepositoryProvider)
          .checkAvailability(
            email: isEmail ? value : null,
            displayName: isEmail ? null : value,
          );
      result = switch (isEmail ? answer.email : answer.displayName) {
        true => Availability.available,
        false => Availability.taken,
        null => Availability.unknown,
      };
    } on Object {
      // A failed check doesn't hold the form: registration still refuses a
      // taken value, and says so on the field.
      result = Availability.unknown;
    }
    if (!ref.mounted || _requestIds[field] != requestId) return;
    state = state._with(field, result);
  }
}

/// Auto-disposed so the next visit to the form starts with nothing checked.
final registerAvailabilityProvider =
    NotifierProvider.autoDispose<
      RegisterAvailabilityController,
      RegisterAvailability
    >(RegisterAvailabilityController.new);
