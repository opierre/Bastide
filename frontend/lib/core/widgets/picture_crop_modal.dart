import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../pictures/pictures.dart';
import '../theme/tokens.dart';
import 'app_modal.dart';
import 'inline_banner.dart';
import 'primary_button.dart';

const _viewport = 320.0;
const _maxZoom = 5.0;

// Scroll distance per e-fold of zoom. Flutter's default (200) zooms ~1.6× per
// wheel notch; 1000 gives ~1.1× steps, fine enough to frame a face precisely.
const _wheelZoomFactor = 1000.0;

/// The square crop step between picking a picture and uploading it: the user
/// drags and zooms the picture under a square window, and what shows through
/// the window is what [onSave] receives, in image pixels.
///
/// The caller owns the upload: it passes the labels, whether the upload is
/// [busy], the [failureMessage] of the last attempt, and closes nothing —
/// [onSave] resolving to `true` closes the modal. Disposes [image].
class PictureCropModal extends StatefulWidget {
  const PictureCropModal({
    super.key,
    required this.image,
    required this.title,
    required this.lead,
    required this.cancelLabel,
    required this.saveLabel,
    required this.busy,
    required this.onSave,
    this.failureMessage,
  });

  final ui.Image image;
  final String title;
  final String lead;
  final String cancelLabel;
  final String saveLabel;
  final bool busy;
  final Future<bool> Function(ui.Image image, Rect crop) onSave;
  final String? failureMessage;

  @override
  State<PictureCropModal> createState() => _PictureCropModalState();
}

class _PictureCropModalState extends State<PictureCropModal> {
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
    final saved = await widget.onSave(widget.image, crop);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;
    return AppModal(
      title: widget.title,
      width: 420,
      actions: [
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        PrimaryButton(
          key: const Key('pictureCropSave'),
          label: widget.saveLabel,
          isLoading: busy,
          onPressed: busy ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.lead,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              key: const Key('pictureCropViewport'),
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
                scaleFactor: _wheelZoomFactor,
                child: SizedBox(
                  width: _imageSize.width * _scale,
                  height: _imageSize.height * _scale,
                  child: RawImage(image: widget.image, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          if (widget.failureMessage case final message?) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(message: message),
          ],
        ],
      ),
    );
  }
}
