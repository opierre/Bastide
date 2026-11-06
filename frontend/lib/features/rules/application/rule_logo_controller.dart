import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/pictures/pictures.dart';
import '../data/rules_repository.dart';
import 'rules_controller.dart';

@immutable
class RuleLogoState {
  const RuleLogoState({this.busy = false, this.failure});

  final bool busy;

  /// Why the last pick, upload or removal didn't change the logo. Cleared by
  /// the next attempt.
  final PictureUploadFailure? failure;
}

/// Picks, crops and uploads a rule's logo from the rule editor, and removes
/// it.
///
/// Each change folds the returned rule into [rulesControllerProvider] and
/// re-reads the views showing merchant chips, so every matching row in
/// Transactions and Abonnements switches at once.
class RuleLogoController extends Notifier<RuleLogoState> {
  @override
  RuleLogoState build() => const RuleLogoState();

  /// Opens the picker and decodes the file for the crop step. Returns `null`
  /// when the user cancelled or the file was refused; [state] then says why.
  Future<ui.Image?> pick() async {
    state = const RuleLogoState(busy: true);
    try {
      final image = await pickPicture(ref);
      state = const RuleLogoState();
      return image;
    } on PictureUploadFailure catch (failure) {
      return _fail(failure);
    } catch (_) {
      return _fail(PictureUploadFailure.generic);
    }
  }

  /// Uploads the [crop] of [image] as rule [ruleId]'s logo. Returns whether
  /// the logo changed.
  Future<bool> upload(String ruleId, ui.Image image, Rect crop) async {
    state = const RuleLogoState(busy: true);
    try {
      final png = await ref.read(pictureImagingProvider).cropToPng(image, crop);
      final rule = await ref
          .read(rulesRepositoryProvider)
          .uploadLogo(ruleId, png);
      await ref.read(rulesControllerProvider.notifier).logoChanged(rule);
      state = const RuleLogoState();
      return true;
    } on ApiFailure catch (failure) {
      _fail(switch (failure.code) {
        'RULE_LOGO_TOO_LARGE' => PictureUploadFailure.tooLarge,
        'RULE_LOGO_INVALID_IMAGE' => PictureUploadFailure.invalidType,
        _ => PictureUploadFailure.generic,
      });
      return false;
    } catch (_) {
      _fail(PictureUploadFailure.generic);
      return false;
    }
  }

  /// Drops rule [ruleId]'s logo; its rows show their monogram again.
  Future<void> remove(String ruleId) async {
    state = const RuleLogoState(busy: true);
    try {
      final rule = await ref.read(rulesRepositoryProvider).removeLogo(ruleId);
      await ref.read(rulesControllerProvider.notifier).logoChanged(rule);
      state = const RuleLogoState();
    } catch (_) {
      _fail(PictureUploadFailure.generic);
    }
  }

  Null _fail(PictureUploadFailure failure) {
    state = RuleLogoState(failure: failure);
    return null;
  }
}

final ruleLogoControllerProvider =
    NotifierProvider.autoDispose<RuleLogoController, RuleLogoState>(
      RuleLogoController.new,
    );
