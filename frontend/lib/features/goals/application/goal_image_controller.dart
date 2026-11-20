import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pictures/pictures.dart';
import 'goals_controller.dart';

/// The size a cropped banner is uploaded at: twice the backend's 880 × 380,
/// so its own downscale has pixels to work with. 44:19, like the banner.
const bannerUploadSize = Size(1760, 760);

@immutable
class GoalImageState {
  const GoalImageState({this.busy = false, this.failure});

  final bool busy;

  /// Why the last pick or upload didn't change the image. Cleared by the next
  /// attempt.
  final PictureUploadFailure? failure;
}

/// Picks and crops a goal's banner image, with the avatar's picker and crop
/// step (`docs/design/11-goals.md` §Banner image), and uploads it from the
/// inspector.
///
/// The goal form only picks and crops: it holds the PNG until the goal is
/// saved, so [crop] returns the bytes without uploading them.
class GoalImageController extends Notifier<GoalImageState> {
  @override
  GoalImageState build() => const GoalImageState();

  /// Opens the picker and decodes the file for the crop step. Returns `null`
  /// when the user cancelled or the file was refused; [state] then says why.
  Future<ui.Image?> pick() async {
    state = const GoalImageState(busy: true);
    try {
      final image = await pickPicture(ref);
      state = const GoalImageState();
      return image;
    } on PictureUploadFailure catch (failure) {
      return _fail(failure);
    } catch (_) {
      return _fail(PictureUploadFailure.generic);
    }
  }

  /// The [crop] of [image] as the PNG the backend takes, or `null` when it
  /// could not be rendered.
  Future<Uint8List?> crop(ui.Image image, Rect crop) async {
    state = const GoalImageState(busy: true);
    try {
      final png = await ref
          .read(pictureImagingProvider)
          .cropToPng(image, crop, output: bannerUploadSize);
      state = const GoalImageState();
      return png;
    } catch (_) {
      return _fail(PictureUploadFailure.generic);
    }
  }

  /// Uploads the [crop] of [image] as goal [goalId]'s banner. Returns whether
  /// the image changed.
  Future<bool> upload(String goalId, ui.Image image, Rect crop) async {
    final png = await this.crop(image, crop);
    if (png == null) return false;
    state = const GoalImageState(busy: true);
    try {
      await ref.read(goalsControllerProvider.notifier).uploadImage(goalId, png);
      state = const GoalImageState();
      return true;
    } catch (error) {
      _fail(goalImageFailureOf(error));
      return false;
    }
  }

  /// Forgets the last failure, when the user leaves the step that showed it.
  void reset() => state = const GoalImageState();

  Null _fail(PictureUploadFailure failure) {
    state = GoalImageState(failure: failure);
    return null;
  }
}

/// Kept alive between the pick and the crop step, which read it in turn.
final goalImageControllerProvider =
    NotifierProvider<GoalImageController, GoalImageState>(
      GoalImageController.new,
    );
