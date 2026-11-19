import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The slider of `docs/design/00-design-system.md` §6: a 4 px `lineStrong`
/// track, an `accent` fill up to the value, and a 14 px `text` thumb with a
/// 2 px `bg` ring.
///
/// Built on Material's [Slider] with replaced shapes rather than from scratch:
/// drag, keyboard arrows, focus and the semantics a screen reader announces all
/// come from it, and none of that is worth reimplementing to change how three
/// shapes are painted.
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
    // Disabled is 45 % opacity (`00` §6) rather than Material's own greyed
    // colours, like every other control.
    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: SizedBox(
        width: width,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _trackHeight,
            trackShape: const _FilledTrackShape(),
            thumbShape: const _RingedThumbShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            overlayColor: context.colors.accentSoft,
            activeTrackColor: context.colors.accent,
            inactiveTrackColor: context.colors.lineStrong,
            thumbColor: context.colors.text,
            disabledActiveTrackColor: context.colors.accent,
            disabledInactiveTrackColor: context.colors.lineStrong,
            disabledThumbColor: context.colors.text,
            overlappingShapeStrokeColor: context.colors.bg,
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
      ),
    );
  }
}

const _trackHeight = 4.0;

/// The 14 px thumb plus its 2 px ring.
const _thumbRadius = 9.0;
const _ringWidth = 2.0;

/// The track: a full-width rail with the fill painted over the portion left of
/// the thumb.
class _FilledTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _FilledTrackShape();

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
      Paint()..color = sliderTheme.inactiveTrackColor!,
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
      Paint()..color = sliderTheme.activeTrackColor!,
    );
  }
}

/// The thumb: a disc ringed in the ground colour, which
/// [RoundSliderThumbShape] cannot draw.
class _RingedThumbShape extends SliderComponentShape {
  const _RingedThumbShape();

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
      center,
      _thumbRadius,
      Paint()..color = sliderTheme.overlappingShapeStrokeColor!,
    );
    canvas.drawCircle(
      center,
      _thumbRadius - _ringWidth,
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}
