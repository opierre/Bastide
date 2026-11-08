import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picking a picture file and cropping it to a square, shared by every
/// upload the backend re-encodes as a square PNG: the user's avatar and a
/// rule's logo.

/// The largest picture file the backend accepts (`MAX_UPLOAD_BYTES` in
/// `app/core/images.py`). Checked before the file is read, so an oversized
/// one is refused at once.
const maxPictureUploadBytes = 10 * 1024 * 1024;

/// Side of the square the cropped picture is uploaded at: twice the
/// backend's 256 px, so its own downscale has pixels to work with.
const croppedPictureSize = 512;

/// Why a picture could not be uploaded. Whatever it was replacing is left as
/// it was in every case.
enum PictureUploadFailure { tooLarge, invalidType, generic }

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
class PictureFiles {
  const PictureFiles();

  /// Returns `null` if the user cancelled.
  Future<PickedPictureFile?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return null;
    return (length: await file.length(), read: file.readAsBytes);
  }
}

final pictureFilesProvider = Provider<PictureFiles>(
  (ref) => const PictureFiles(),
);

/// Decodes a picked file and renders the cropped square, through the
/// engine's own codecs. Behind a provider so widget tests don't depend on
/// real image decoding.
class PictureImaging {
  const PictureImaging();

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
    const side = croppedPictureSize * 1.0;
    Canvas(recorder).drawImageRect(
      image,
      crop,
      const Rect.fromLTWH(0, 0, side, side),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final square = await picture.toImage(
      croppedPictureSize,
      croppedPictureSize,
    );
    picture.dispose();
    try {
      final data = await square.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      square.dispose();
    }
  }
}

final pictureImagingProvider = Provider<PictureImaging>(
  (ref) => const PictureImaging(),
);

/// Picks a picture file and decodes it for the crop step.
///
/// Returns the decoded image, `null` when the user cancelled, or throws the
/// [PictureUploadFailure] that refused the file — too large, or not a
/// picture.
Future<ui.Image?> pickPicture(Ref ref) async {
  final file = await ref.read(pictureFilesProvider).pick();
  if (file == null) return null;
  if (file.length > maxPictureUploadBytes) throw PictureUploadFailure.tooLarge;
  final bytes = await file.read();
  try {
    return await ref.read(pictureImagingProvider).decode(bytes);
  } catch (_) {
    throw PictureUploadFailure.invalidType;
  }
}

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
