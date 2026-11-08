import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/picture_crop_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/avatar_picture_controllers.dart';
import 'avatar_upload_failure_text.dart';

/// The square crop step between picking a picture and making it the avatar.
class AvatarCropModal extends ConsumerWidget {
  const AvatarCropModal({super.key, required this.image});

  final ui.Image image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(profilePictureControllerProvider);
    return PictureCropModal(
      image: image,
      title: l10n.settingsAvatarCropTitle,
      lead: l10n.settingsAvatarCropLead,
      cancelLabel: l10n.settingsAvatarCropCancel,
      saveLabel: l10n.settingsAvatarCropSave,
      busy: state.busy,
      failureMessage: switch (state.failure) {
        final failure? => avatarUploadFailureText(l10n, failure),
        null => null,
      },
      onSave: ref.read(profilePictureControllerProvider.notifier).upload,
    );
  }
}
