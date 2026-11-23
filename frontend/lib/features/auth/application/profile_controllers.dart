import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/avatar_choice.dart';
import '../domain/text_size_preference.dart';
import '../domain/theme_preference.dart';
import 'auth_controller.dart';

/// Renames the user from Settings › Profil. Separate from [AuthController] so
/// a taken name errors the modal alone, not the whole session.
class DisplayNameController extends AsyncNotifier<void> {
  @override
  // Synchronous, so the modal opens idle rather than loading for a frame.
  FutureOr<void> build() {}

  Future<void> save({required String displayName}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(displayName: displayName);
      ref.read(authControllerProvider.notifier).replaceUser(user);
    });
  }
}

/// Auto-disposed with the modal, so a stale error doesn't greet its next
/// opening.
final displayNameControllerProvider =
    AsyncNotifierProvider.autoDispose<DisplayNameController, void>(
      DisplayNameController.new,
    );

/// Changes the email from Settings › Profil. Separate from [AuthController]
/// so a taken address or a wrong password errors the modal alone, not the
/// whole session.
class EmailChangeController extends AsyncNotifier<void> {
  @override
  // Synchronous, so the modal opens idle rather than loading for a frame.
  FutureOr<void> build() {}

  Future<void> save({
    required String email,
    required String currentPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .changeEmail(email: email, currentPassword: currentPassword);
      ref.read(authControllerProvider.notifier).replaceUser(user);
    });
  }
}

/// Auto-disposed with the modal, so a stale error doesn't greet its next
/// opening.
final emailChangeControllerProvider =
    AsyncNotifierProvider.autoDispose<EmailChangeController, void>(
      EmailChangeController.new,
    );

/// Changes the password from Settings › Profil. Separate from
/// [AuthController] so a wrong current password errors the modal alone, not
/// the whole session.
class PasswordChangeController extends AsyncNotifier<void> {
  @override
  // Synchronous, so the modal opens idle rather than loading for a frame.
  FutureOr<void> build() {}

  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          ),
    );
  }
}

/// Auto-disposed with the modal, so a stale error doesn't greet its next
/// opening.
final passwordChangeControllerProvider =
    AsyncNotifierProvider.autoDispose<PasswordChangeController, void>(
      PasswordChangeController.new,
    );

/// Sets the default avatar from Settings › Profil. The session's user is
/// replaced with the answer, so the card and the top bar follow at once.
class AvatarChoiceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(AvatarChoice choice) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .setAvatarChoice(choice);
      ref.read(authControllerProvider.notifier).replaceUser(user);
    });
  }
}

final avatarChoiceControllerProvider =
    AsyncNotifierProvider.autoDispose<AvatarChoiceController, void>(
      AvatarChoiceController.new,
    );

/// Sets the theme from Settings › Préférences. The session's user takes the
/// new theme before the request goes out, so the whole app switches at once;
/// a refusal puts the previous theme back and leaves the error in [state].
class ThemePreferenceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(ThemePreference theme) async {
    final auth = ref.read(authControllerProvider.notifier);
    final previous = ref.read(authControllerProvider).value;
    if (previous == null || previous.theme == theme) return;

    auth.replaceUser(previous.withTheme(theme));
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        auth.replaceUser(
          await ref.read(authRepositoryProvider).setTheme(theme),
        );
      } catch (_) {
        auth.replaceUser(previous);
        rethrow;
      }
    });
  }
}

final themePreferenceControllerProvider =
    AsyncNotifierProvider.autoDispose<ThemePreferenceController, void>(
      ThemePreferenceController.new,
    );

/// Sets the text size from Settings › Préférences, like the theme: the
/// session's user takes it before the request goes out, so every text in the
/// app resizes at once; a refusal puts the previous size back and leaves the
/// error in [state].
class TextSizePreferenceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(TextSizePreference textSize) async {
    final auth = ref.read(authControllerProvider.notifier);
    final previous = ref.read(authControllerProvider).value;
    if (previous == null || previous.textSize == textSize) return;

    auth.replaceUser(previous.withTextSize(textSize));
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        auth.replaceUser(
          await ref.read(authRepositoryProvider).setTextSize(textSize),
        );
      } catch (_) {
        auth.replaceUser(previous);
        rethrow;
      }
    });
  }
}

final textSizePreferenceControllerProvider =
    AsyncNotifierProvider.autoDispose<TextSizePreferenceController, void>(
      TextSizePreferenceController.new,
    );
