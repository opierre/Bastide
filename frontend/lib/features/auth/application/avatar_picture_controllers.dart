import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/pictures/pictures.dart';
import '../data/auth_repository.dart';
import '../domain/avatar_choice.dart';
import '../domain/avatar_picture.dart';
import 'auth_controller.dart';

/// The uploaded picture the top bar and Settings › Profil show, kept in
/// memory and revalidated by ETag, so a rebuild never downloads it again.
///
/// `null` whenever the avatar isn't a picture, or it couldn't be fetched:
/// the avatar then falls back to the monogram.
class AvatarPictureController extends AsyncNotifier<AvatarPicture?> {
  AvatarPicture? _cached;

  @override
  Future<AvatarPicture?> build() async {
    final user = ref.watch(
      authControllerProvider.select(
        (state) => (id: state.value?.id, avatar: state.value?.avatar),
      ),
    );
    if (user.avatar is! PictureChoice) {
      _cached = null;
      return null;
    }
    return _revalidate();
  }

  /// Fetches again after the picture changed on the backend.
  Future<void> refresh() async {
    state = AsyncValue.data(await _revalidate());
  }

  Future<AvatarPicture?> _revalidate() async {
    try {
      final fresh = await ref
          .read(authRepositoryProvider)
          .fetchAvatar(etag: _cached?.etag);
      if (fresh != null) _cached = fresh;
    } on ApiFailure catch (failure) {
      if (failure.code == 'AVATAR_NOT_FOUND') _cached = null;
    }
    return _cached;
  }
}

final avatarPictureProvider =
    AsyncNotifierProvider<AvatarPictureController, AvatarPicture?>(
      AvatarPictureController.new,
    );

@immutable
class ProfilePictureState {
  const ProfilePictureState({this.busy = false, this.failure});

  final bool busy;

  /// Why the last pick or upload didn't change the avatar. Cleared by the
  /// next attempt.
  final PictureUploadFailure? failure;
}

/// Picks, crops and uploads a picture from Settings › Profil, and removes it.
class ProfilePictureController extends Notifier<ProfilePictureState> {
  @override
  ProfilePictureState build() => const ProfilePictureState();

  /// Opens the picker and decodes the file for the crop step. Returns `null`
  /// when the user cancelled or the file was refused; [state] then says why.
  Future<ui.Image?> pick() async {
    state = const ProfilePictureState(busy: true);
    try {
      final image = await pickPicture(ref);
      state = const ProfilePictureState();
      return image;
    } on PictureUploadFailure catch (failure) {
      return _fail(failure);
    } catch (_) {
      return _fail(PictureUploadFailure.generic);
    }
  }

  /// Uploads the [crop] of [image]. Returns whether the avatar changed.
  Future<bool> upload(ui.Image image, Rect crop) async {
    state = const ProfilePictureState(busy: true);
    try {
      final png = await ref.read(pictureImagingProvider).cropToPng(image, crop);
      final user = await ref.read(authRepositoryProvider).uploadAvatar(png);
      ref.read(authControllerProvider.notifier).replaceUser(user);
      await ref.read(avatarPictureProvider.notifier).refresh();
      state = const ProfilePictureState();
      return true;
    } on ApiFailure catch (failure) {
      _fail(switch (failure.code) {
        'AVATAR_TOO_LARGE' => PictureUploadFailure.tooLarge,
        'AVATAR_INVALID_IMAGE' => PictureUploadFailure.invalidType,
        _ => PictureUploadFailure.generic,
      });
      return false;
    } catch (_) {
      _fail(PictureUploadFailure.generic);
      return false;
    }
  }

  /// Drops the picture; the backend brings back the previous default.
  Future<void> remove() async {
    state = const ProfilePictureState(busy: true);
    try {
      final user = await ref.read(authRepositoryProvider).removeAvatar();
      ref.read(authControllerProvider.notifier).replaceUser(user);
      state = const ProfilePictureState();
    } catch (_) {
      _fail(PictureUploadFailure.generic);
    }
  }

  Null _fail(PictureUploadFailure failure) {
    state = ProfilePictureState(failure: failure);
    return null;
  }
}

final profilePictureControllerProvider =
    NotifierProvider.autoDispose<ProfilePictureController, ProfilePictureState>(
      ProfilePictureController.new,
    );
