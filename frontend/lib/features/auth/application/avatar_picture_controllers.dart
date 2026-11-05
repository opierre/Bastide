import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/avatar_choice.dart';
import '../domain/avatar_picture.dart';
import 'auth_controller.dart';

/// Side of the square the cropped picture is uploaded at: twice the
/// backend's 256 px, so its own downscale has pixels to work with.
const croppedAvatarSize = 512;

const _typeGroup = XTypeGroup(
  label: 'PNG, JPEG, WebP',
  extensions: ['png', 'jpg', 'jpeg', 'webp'],
  mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
);

/// A picture file the user picked: its size first, so an oversized file is
/// refused before it is read.
typedef PickedPictureFile = ({int length, Future<Uint8List> Function() read});

/// Opens the native picker. Behind a provider so tests pick without a
/// platform channel — the same seam as `BackupFiles`.
class AvatarFiles {
  const AvatarFiles();

  /// Returns `null` if the user cancelled.
  Future<PickedPictureFile?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return null;
    return (length: await file.length(), read: file.readAsBytes);
  }
}

final avatarFilesProvider = Provider<AvatarFiles>((ref) => const AvatarFiles());

/// Decodes a picked file and renders the cropped square, through the
/// engine's own codecs. Behind a provider so widget tests don't depend on
/// real image decoding.
class AvatarImaging {
  const AvatarImaging();

  /// Throws when [bytes] are not a picture the engine can decode.
  Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// The [crop] of [image], in image pixels, scaled to a square PNG.
  Future<Uint8List> cropToPng(ui.Image image, Rect crop) async {
    final recorder = ui.PictureRecorder();
    const side = croppedAvatarSize * 1.0;
    Canvas(recorder).drawImageRect(
      image,
      crop,
      const Rect.fromLTWH(0, 0, side, side),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final square = await picture.toImage(croppedAvatarSize, croppedAvatarSize);
    picture.dispose();
    try {
      final data = await square.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      square.dispose();
    }
  }
}

final avatarImagingProvider = Provider<AvatarImaging>(
  (ref) => const AvatarImaging(),
);

/// The cover scale that makes an image of [imageSize] fill a square
/// [viewport] along its shorter side.
double coverScale(Size imageSize, double viewport) =>
    viewport / imageSize.shortestSide;

/// The square of the image, in image pixels, that shows through a square
/// [viewport] of the crop step.
///
/// The image is laid out at [coverScale], then moved and zoomed by the
/// viewer's [transform] (a scale-and-translate matrix). The result is clamped
/// to the image, so a rounding error can never sample outside it.
Rect cropRectFor({
  required Size imageSize,
  required double viewport,
  required Matrix4 transform,
}) {
  final zoom = transform.getMaxScaleOnAxis();
  final translation = transform.getTranslation();
  final scale = coverScale(imageSize, viewport) * zoom;
  final side = (viewport / scale).clamp(1.0, imageSize.shortestSide);
  final left = (-translation.x / scale).clamp(0.0, imageSize.width - side);
  final top = (-translation.y / scale).clamp(0.0, imageSize.height - side);
  return Rect.fromLTWH(left, top, side, side);
}

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
  final AvatarUploadFailure? failure;
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
      final file = await ref.read(avatarFilesProvider).pick();
      if (file == null) {
        state = const ProfilePictureState();
        return null;
      }
      if (file.length > maxAvatarUploadBytes) {
        return _fail(AvatarUploadFailure.tooLarge);
      }
      final bytes = await file.read();
      final ui.Image image;
      try {
        image = await ref.read(avatarImagingProvider).decode(bytes);
      } catch (_) {
        return _fail(AvatarUploadFailure.invalidType);
      }
      state = const ProfilePictureState();
      return image;
    } catch (_) {
      return _fail(AvatarUploadFailure.generic);
    }
  }

  /// Uploads the [crop] of [image]. Returns whether the avatar changed.
  Future<bool> upload(ui.Image image, Rect crop) async {
    state = const ProfilePictureState(busy: true);
    try {
      final png = await ref.read(avatarImagingProvider).cropToPng(image, crop);
      final user = await ref.read(authRepositoryProvider).uploadAvatar(png);
      ref.read(authControllerProvider.notifier).replaceUser(user);
      await ref.read(avatarPictureProvider.notifier).refresh();
      state = const ProfilePictureState();
      return true;
    } on ApiFailure catch (failure) {
      _fail(switch (failure.code) {
        'AVATAR_TOO_LARGE' => AvatarUploadFailure.tooLarge,
        'AVATAR_INVALID_IMAGE' => AvatarUploadFailure.invalidType,
        _ => AvatarUploadFailure.generic,
      });
      return false;
    } catch (_) {
      _fail(AvatarUploadFailure.generic);
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
      _fail(AvatarUploadFailure.generic);
    }
  }

  Null _fail(AvatarUploadFailure failure) {
    state = ProfilePictureState(failure: failure);
    return null;
  }
}

final profilePictureControllerProvider =
    NotifierProvider.autoDispose<ProfilePictureController, ProfilePictureState>(
      ProfilePictureController.new,
    );
