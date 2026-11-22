import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../l10n/app_localizations.dart';
import '../pictures/pictures.dart';
import '../theme/tokens.dart';
import 'app_modal.dart';
import 'app_slider.dart';
import 'focus_ring.dart';
import 'primary_button.dart';

// Scroll distance per e-fold of zoom. Flutter's default (200) zooms ~1.6× per
// wheel notch; 1000 gives ~1.1× steps, fine enough to frame a face precisely.
const _wheelZoomFactor = 1000.0;

/// One + / − press: the same step as a wheel notch.
const _keyZoomStep = 1.1;

/// One arrow press moves the picture by this much of the window.
const _keyMoveStep = AppSpacing.sm;

/// The slider snaps to tenths, the precision the value is printed with.
const _zoomDivisions = 40;

/// The crop step between picking a picture and uploading it (`00` §7
/// « Modal », Crop): the lead says what to do, the body holds the window the
/// picture shows through, and under it a « Zoom » slider from 1 to 5 × with
/// its value printed. Drag moves; wheel, pinch or the slider zoom; with the
/// window focused, arrow keys move and + / − zoom. What shows through the
/// window is what [onSave] receives, in image pixels.
///
/// The window is the square [AppModalSizes.cropSquare] unless [viewport]
/// gives the body's full width at another ratio. [round] draws the round
/// avatar's circle and veils the corners with `scrim`.
///
/// The caller owns the upload: it passes the labels, whether the upload is
/// [busy], the [failureMessage] of the last attempt, and closes nothing:
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
    this.viewport = const Size.square(AppModalSizes.cropSquare),
    this.width = AppModalSizes.w420,
    this.round = false,
  });

  final ui.Image image;
  final String title;
  final String lead;
  final String cancelLabel;
  final String saveLabel;
  final bool busy;
  final Future<bool> Function(ui.Image image, Rect crop) onSave;
  final String? failureMessage;

  /// The window the picture shows through; its proportions are the crop's.
  final Size viewport;

  /// The modal's width, given per panel (`00` §7).
  final double width;

  /// Draws the avatar's circle over a square window.
  final bool round;

  @override
  State<PictureCropModal> createState() => _PictureCropModalState();
}

class _PictureCropModalState extends State<PictureCropModal> {
  late final Size _imageSize = Size(
    widget.image.width.toDouble(),
    widget.image.height.toDouble(),
  );
  late final double _scale = coverScaleIn(_imageSize, widget.viewport);

  // Opens centred, so the default crop is the picture's middle.
  late final _transform = TransformationController(
    Matrix4.translationValues(
      -(_imageSize.width * _scale - widget.viewport.width) / 2,
      -(_imageSize.height * _scale - widget.viewport.height) / 2,
      0,
    ),
  );

  bool _windowFocused = false;

  @override
  void initState() {
    super.initState();
    // The printed value and the slider follow the wheel and the pinch too.
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    widget.image.dispose();
    super.dispose();
  }

  void _onTransform() => setState(() {});

  double get _zoom => _transform.value.getMaxScaleOnAxis();

  /// Sets zoom and offset at once, keeping the window covered by the picture.
  void _apply(double zoom, Offset translation) {
    final size = _imageSize * _scale * zoom;
    final x = translation.dx.clamp(widget.viewport.width - size.width, 0.0);
    final y = translation.dy.clamp(widget.viewport.height - size.height, 0.0);
    _transform.value = Matrix4.translationValues(x, y, 0)
      ..multiply(Matrix4.diagonal3Values(zoom, zoom, 1));
  }

  Offset get _translation {
    final t = _transform.value.getTranslation();
    return Offset(t.x, t.y);
  }

  /// Zooms about the window's centre, so the framed subject stays put.
  void _zoomTo(double zoom) {
    final target = zoom.clamp(
      AppModalSizes.cropMinZoom,
      AppModalSizes.cropMaxZoom,
    );
    final centre = widget.viewport.center(Offset.zero);
    final point = (centre - _translation) / _zoom;
    _apply(target, centre - point * target);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final move = switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(_keyMoveStep, 0),
      LogicalKeyboardKey.arrowRight => const Offset(-_keyMoveStep, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, _keyMoveStep),
      LogicalKeyboardKey.arrowDown => const Offset(0, -_keyMoveStep),
      _ => null,
    };
    if (move != null) {
      _apply(_zoom, _translation + move);
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (key == LogicalKeyboardKey.numpadAdd ||
        character == '+' ||
        character == '=') {
      _zoomTo(_zoom * _keyZoomStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.minus ||
        character == '-') {
      _zoomTo(_zoom / _keyZoomStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _save() async {
    final crop = cropRectIn(
      imageSize: _imageSize,
      viewport: widget.viewport,
      transform: _transform.value,
    );
    final saved = await widget.onSave(widget.image, crop);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final busy = widget.busy;
    final viewport = widget.viewport;
    final number = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toString(),
    );
    String printed(double zoom) => l10n.modalCropZoomValue(number.format(zoom));

    final window = Focus(
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _windowFocused = focused),
      child: Semantics(
        label: l10n.modalCropWindow,
        child: FocusRing(
          focused: _windowFocused,
          radius: AppRadii.container,
          child: Container(
            key: const Key('pictureCropViewport'),
            width: viewport.width,
            height: viewport.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.container),
              border: Border.all(color: colors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  // No margin: the window can't be dragged off the picture.
                  boundaryMargin: EdgeInsets.zero,
                  minScale: AppModalSizes.cropMinZoom,
                  maxScale: AppModalSizes.cropMaxZoom,
                  scaleFactor: _wheelZoomFactor,
                  child: SizedBox(
                    width: _imageSize.width * _scale,
                    height: _imageSize.height * _scale,
                    child: RawImage(image: widget.image, fit: BoxFit.fill),
                  ),
                ),
                if (widget.round)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('pictureCropGuide'),
                        painter: _AvatarGuidePainter(veil: colors.scrim),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final iconColor = colors.textTertiary;
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final zoomRow = SizedBox(
      width: viewport.width,
      child: Row(
        children: [
          Icon(
            LucideIcons300.zoomOut,
            size: AppSizes.iconSmall,
            color: iconColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AppSlider(
                key: const Key('pictureCropZoom'),
                width: constraints.maxWidth,
                value: _zoom,
                min: AppModalSizes.cropMinZoom,
                max: AppModalSizes.cropMaxZoom,
                divisions: _zoomDivisions,
                semanticFormatter: printed,
                onChanged: busy ? null : _zoomTo,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            LucideIcons300.zoomIn,
            size: AppSizes.iconSmall,
            color: iconColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Sized to the widest value, so the slider never shifts as the
          // printed figure changes.
          Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              ExcludeSemantics(
                child: Visibility.maintain(
                  visible: false,
                  child: Text(
                    printed(AppModalSizes.cropMaxZoom),
                    style: valueStyle,
                  ),
                ),
              ),
              Text(
                printed(_zoom),
                key: const Key('pictureCropZoomValue'),
                style: valueStyle,
              ),
            ],
          ),
        ],
      ),
    );

    return AppModal(
      title: widget.title,
      subtitle: Text(widget.lead),
      width: widget.width,
      busy: busy,
      saveError: widget.failureMessage,
      actions: [
        AppModalCancel(label: widget.cancelLabel),
        PrimaryButton(
          key: const Key('pictureCropSave'),
          label: widget.saveLabel,
          isLoading: busy,
          onPressed: _save,
        ),
      ],
      child: Column(
        children: [
          Semantics(container: true, child: window),
          const SizedBox(height: AppSpacing.fieldGap),
          Semantics(container: true, label: l10n.modalCropZoom, child: zoomRow),
        ],
      ),
    );
  }
}

/// The round avatar's circle over the square window, and the `scrim` over
/// the corners it will not keep. The circle sits on the photo, not on the
/// theme: 1 px white at 80 % with 1 px black at 30 % outside it.
class _AvatarGuidePainter extends CustomPainter {
  const _AvatarGuidePainter({required this.veil});

  final Color veil;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final circle = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addOval(circle),
      ),
      Paint()..color = veil,
    );
    const half = AppCropGuide.width / 2;
    canvas
      ..drawCircle(
        centre,
        radius - half,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppCropGuide.width
          ..color = AppCropGuide.ring,
      )
      ..drawCircle(
        centre,
        radius + half,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppCropGuide.width
          ..color = AppCropGuide.ringShadow,
      );
  }

  @override
  bool shouldRepaint(_AvatarGuidePainter oldDelegate) =>
      oldDelegate.veil != veil;
}
