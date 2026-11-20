import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picking a picture file and cropping it, shared by every upload the
/// backend re-encodes as a PNG: the user's avatar and a rule's logo (square),
/// and a goal's banner (44:19).

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

  /// The [crop] of [image], in image pixels, scaled to an [output]-sized
  /// PNG: a [croppedPictureSize] square unless told otherwise.
  Future<Uint8List> cropToPng(
    ui.Image image,
    Rect crop, {
    Size output = const Size.square(croppedPictureSize * 1.0),
  }) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      crop,
      Offset.zero & output,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(
      output.width.round(),
      output.height.round(),
    );
    picture.dispose();
    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      cropped.dispose();
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
    coverScaleIn(imageSize, Size.square(viewport));

/// The cover scale that makes an image of [imageSize] fill a [viewport] of
/// any shape: no gap on either axis.
double coverScaleIn(Size imageSize, Size viewport) => math.max(
  viewport.width / imageSize.width,
  viewport.height / imageSize.height,
);

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
}) => cropRectIn(
  imageSize: imageSize,
  viewport: Size.square(viewport),
  transform: transform,
);

/// The part of the image, in image pixels, that shows through a [viewport]
/// of any shape: the same reading as [cropRectFor], keeping the viewport's
/// proportions.
Rect cropRectIn({
  required Size imageSize,
  required Size viewport,
  required Matrix4 transform,
}) {
  final zoom = transform.getMaxScaleOnAxis();
  final translation = transform.getTranslation();
  final scale = coverScaleIn(imageSize, viewport) * zoom;
  final width = (viewport.width / scale).clamp(1.0, imageSize.width);
  final height = (viewport.height / scale).clamp(1.0, imageSize.height);
  final left = (-translation.x / scale).clamp(0.0, imageSize.width - width);
  final top = (-translation.y / scale).clamp(0.0, imageSize.height - height);
  return Rect.fromLTWH(left, top, width, height);
}
