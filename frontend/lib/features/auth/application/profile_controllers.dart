import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/avatar_choice.dart';
import 'auth_controller.dart';

/// Renames the user from Settings › Profil. Separate from [AuthController] so
/// a taken name errors the modal alone, not the whole session.
class DisplayNameController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

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
