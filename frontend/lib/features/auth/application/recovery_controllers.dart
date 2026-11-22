import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// The « Mot de passe oublié » form's submission. Separate from
/// [AuthController] so a failed reset errors this form alone, rather than
/// putting the whole session into an error state the login screen would show.
class PasswordResetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [identifier] is the email or the display name, as at login.
  Future<void> submit({
    required String identifier,
    required String recoveryCode,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .resetPassword(
            identifier: identifier,
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

/// Writes a recovery code to a text file on this machine. Behind a provider
/// so widget tests drive « Enregistrer dans un fichier » without a platform
/// channel, the same seam as `BackupFiles`.
class RecoveryCodeFiles {
  const RecoveryCodeFiles();

  /// Asks where to save and writes [contents]. Returns the chosen path, or
  /// `null` if the user cancelled.
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Text', extensions: ['txt']),
      ],
    );
    if (location == null) return null;
    await XFile.fromData(
      utf8.encode(contents),
      mimeType: 'text/plain',
      name: suggestedName,
    ).saveTo(location.path);
    return location.path;
  }
}

final recoveryCodeFilesProvider = Provider<RecoveryCodeFiles>(
  (ref) => const RecoveryCodeFiles(),
);

/// Generates a replacement recovery code from Settings › Profil. Data is the
/// new plaintext code, `null` until one has been generated.
class RecoveryCodeRegenerateController extends AsyncNotifier<String?> {
  @override
  // Synchronous, so the modal opens idle rather than loading for a frame.
  FutureOr<String?> build() => null;

  Future<void> regenerate({required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .regenerateRecoveryCode(password: password),
    );
  }

  /// Writes the code just generated to a text file the user picks. Resolves
  /// to `true` once written, `false` when the user cancelled the dialog;
  /// throws when the file cannot be written.
  Future<bool> saveToFile({required String suggestedName}) async {
    final code = state.value;
    if (code == null) return false;
    final path = await ref
        .read(recoveryCodeFilesProvider)
        .save(suggestedName: suggestedName, contents: '$code\n');
    return path != null;
  }
}

/// Auto-disposed with the modal, so the plaintext code is dropped from memory
/// once the user closes it.
final recoveryCodeRegenerateControllerProvider =
    AsyncNotifierProvider.autoDispose<
      RecoveryCodeRegenerateController,
      String?
    >(RecoveryCodeRegenerateController.new);
