import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pictures/picture_download.dart';

@immutable
class RuleLogoUrlState {
  const RuleLogoUrlState({this.busy = false, this.failure});

  final bool busy;

  /// Why the last download didn't give a picture. Cleared by the next one.
  final PictureDownloadFailure? failure;
}

/// Downloads a rule's logo from an address the user pasted, for the same
/// crop step as a picked file.
///
/// Nothing is fetched until the user confirms the address; the crop step
/// then uploads through [RuleLogoController] like any other picture.
class RuleLogoUrlController extends Notifier<RuleLogoUrlState> {
  @override
  RuleLogoUrlState build() => const RuleLogoUrlState();

  /// Downloads and decodes the picture at [address]. Returns `null` when it
  /// was refused; [state] then says why.
  Future<ui.Image?> fetch(String address) async {
    state = const RuleLogoUrlState(busy: true);
    try {
      final image = await downloadPicture(ref, address);
      state = const RuleLogoUrlState();
      return image;
    } on PictureDownloadFailure catch (failure) {
      state = RuleLogoUrlState(failure: failure);
      return null;
    } catch (_) {
      state = const RuleLogoUrlState(
        failure: PictureDownloadFailure.unreachable,
      );
      return null;
    }
  }
}

final ruleLogoUrlControllerProvider =
    NotifierProvider.autoDispose<RuleLogoUrlController, RuleLogoUrlState>(
      RuleLogoUrlController.new,
    );
