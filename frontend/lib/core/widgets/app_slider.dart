import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The spec's slider (`docs/design/00` §Gestion & AI additions): a 5px `#1E2634`
/// track, an iris-gradient fill up to the value, and a 16px `#EDF1F7` thumb
/// carrying `0 2px 8px rgba(0,0,0,.5)`.
///
/// Built on Material's [Slider] with replaced shapes rather than from scratch:
/// drag, keyboard arrows, focus and the semantics a screen reader announces all
/// come from it, and none of that is worth reimplementing to change how three
/// shapes are painted. What [SliderThemeData] alone cannot express is the
/// gradient — its `activeTrackColor` is one flat color — so the track paints
/// itself here.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions = 100,
    this.width = 300,
    this.semanticFormatter,
  });

  final double value;

  /// `null` renders the slider non-interactive.
  final ValueChanged<double>? onChanged;

  final double min;
  final double max;

  /// Steps the thumb snaps to. The default gives whole percents.
  final int divisions;

  /// The drawn width. The slider is a fixed 300px in the mockup rather than a
  /// stretched control: a track as wide as the card would make one percent
  /// smaller than a pointer can aim at.
  final double width;

  /// Turns the raw value into what a screen reader announces — the percentage,
  /// not the bare number.
  final String Function(double)? semanticFormatter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _trackHeight,
          trackShape: const _GradientTrackShape(),
          thumbShape: const _ShadowedThumbShape(),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          overlayColor: AppColors.irisSoft,
          // The value indicator would cover the live percentage in the label
          // above with the same number.
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          semanticFormatterCallback: semanticFormatter,
        ),
      ),
    );
  }
}

const _trackHeight = 5.0;
const _thumbRadius = 8.0;

/// The track: a full-width `#1E2634` rail with the iris gradient painted over
/// the portion left of the thumb.
class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required TextDirection textDirection,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (rect.isEmpty) return;

    final radius = Radius.circular(rect.height / 2);
    final canvas = context.canvas;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = AppColors.surfaceHover,
    );

    final filled = Rect.fromLTRB(
      rect.left,
      rect.top,
      thumbCenter.dx,
      rect.bottom,
    );
    if (filled.width <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(filled, radius),
      Paint()
        // Shaded over the whole track, not over the filled part alone, so the
        // ramp stays anchored as the value moves — a gradient rescaled to the
        // fill would shift hue under a stationary thumb.
        ..shader = AppColors.irisGradient.createShader(rect),
    );
  }
}

/// The thumb: a 16px light disc with the spec's drop shadow, which
/// [RoundSliderThumbShape] has no elevation for on a flat dark surface.
class _ShadowedThumbShape extends SliderComponentShape {
  const _ShadowedThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_thumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 2),
      _thumbRadius,
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      _thumbRadius,
      Paint()..color = AppColors.textPrimary,
    );
  }
}
