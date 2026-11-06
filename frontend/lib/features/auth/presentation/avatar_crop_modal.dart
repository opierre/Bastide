import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/avatar_picture_controllers.dart';
import 'avatar_upload_failure_text.dart';

const _viewport = 320.0;
const _maxZoom = 5.0;

/// The square crop step between picking a picture and uploading it: the user
/// drags and zooms the picture under a square window, and what shows through
/// the window becomes the avatar.
class AvatarCropModal extends ConsumerStatefulWidget {
  const AvatarCropModal({super.key, required this.image});

  final ui.Image image;

  @override
  ConsumerState<AvatarCropModal> createState() => _AvatarCropModalState();
}

class _AvatarCropModalState extends ConsumerState<AvatarCropModal> {
  late final Size _imageSize = Size(
    widget.image.width.toDouble(),
    widget.image.height.toDouble(),
  );
  late final double _scale = coverScale(_imageSize, _viewport);

  // Opens centred, so the default crop is the picture's middle square.
  late final _transform = TransformationController(
    Matrix4.translationValues(
      -(_imageSize.width * _scale - _viewport) / 2,
      -(_imageSize.height * _scale - _viewport) / 2,
      0,
    ),
  );

  @override
  void dispose() {
    _transform.dispose();
    widget.image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final crop = cropRectFor(
      imageSize: _imageSize,
      viewport: _viewport,
      transform: _transform.value,
    );
    final saved = await ref
        .read(profilePictureControllerProvider.notifier)
        .upload(widget.image, crop);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(profilePictureControllerProvider);

    return AppModal(
      title: l10n.settingsAvatarCropTitle,
      width: 420,
      actions: [
        OutlinedButton(
          onPressed: state.busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsAvatarCropCancel),
        ),
        PrimaryButton(
          key: const Key('avatarCropSave'),
          label: l10n.settingsAvatarCropSave,
          isLoading: state.busy,
          onPressed: state.busy ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsAvatarCropLead,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              key: const Key('avatarCropViewport'),
              width: _viewport,
              height: _viewport,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.borderCard),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                // No margin: the window can't be dragged off the picture.
                boundaryMargin: EdgeInsets.zero,
                minScale: 1,
                maxScale: _maxZoom,
                child: SizedBox(
                  width: _imageSize.width * _scale,
                  height: _imageSize.height * _scale,
                  child: RawImage(image: widget.image, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          if (state.failure case final failure?) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(message: avatarUploadFailureText(l10n, failure)),
          ],
        ],
      ),
    );
  }
}
