import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How a [RepereMeter] fills (`docs/design/00-design-system.md` §8).
enum RepereTone {
  /// `accent`: the ordinary reading.
  normal,

  /// `warning`: past a reference the value should stay under.
  over,

  /// `positive`: the target is reached.
  done,

  /// `textTertiary`: archived.
  muted;

  Color fill(AppColors colors) => switch (this) {
    normal => colors.accent,
    over => colors.warning,
    done => colors.positive,
    muted => colors.textTertiary,
  };
}

/// The repère: one component for every value read against a reference
/// (`00` §8). A 4 px `lineStrong` track, radius 2, filled from the left;
/// optionally a 2 × 12 px `text` mark at the reference with its label
/// 11 `textSecondary` centred 5 px above.
///
/// The caller places both on the scale: [fraction] and [markFraction] are
/// positions on the track, 0 at the left end and 1 at the right. The fill
/// clamps at the track's end; the exact value is printed by the caller,
/// beside or above the meter, never inside it.
///
/// When [fraction] changes the fill moves once, 240 ms ease-out; nothing
/// moves on first paint, and nothing at all under the OS "reduce motion"
/// setting (`00` §13).
class RepereMeter extends StatelessWidget {
  const RepereMeter({
    super.key,
    required this.fraction,
    this.tone = RepereTone.normal,
    this.markFraction,
    this.markLabel,
    this.semanticLabel,
  });

  /// The value's position on the track; clamped to 0–1 for drawing.
  final double fraction;

  final RepereTone tone;

  /// The reference's position on the track. No mark when null.
  final double? markFraction;

  /// The mark's label (« objectif 20 % », « repère HCSF 35 % »).
  final String? markLabel;

  /// What a screen reader announces: the printed value, typically.
  final String? semanticLabel;

  static const trackHeight = 4.0;
  static const markWidth = 2.0;
  static const markHeight = 12.0;

  /// Room a meter with a mark reserves above its track.
  static const markReserve = 18.0;

  /// Gap between the mark's label and the top of the track.
  static const _labelGap = 5.0;

  /// How far the mark rises above (and falls below) the track.
  static const _markOverhang = (markHeight - trackHeight) / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mark = markFraction?.clamp(0.0, 1.0);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.meter;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: colors.textSecondary, height: 1.1);

    final track = TweenAnimationBuilder<double>(
      // `end` alone: on first build the tween starts where it ends, so the
      // fill is drawn, not grown; later values animate from the last one.
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, _) => CustomPaint(
        key: const Key('repereTrack'),
        size: Size(0, mark == null ? trackHeight : markHeight),
        painter: _TrackPainter(
          fraction: value,
          fill: tone.fill(colors),
          track: colors.lineStrong,
          mark: mark,
          markColor: colors.text,
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      // No LayoutBuilder: panels measure rows with IntrinsicHeight, which a
      // layout builder cannot answer. The label's delegate reads the width.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mark != null)
            SizedBox(
              // The mark itself rises (12 − 4) / 2 above the track, inside
              // the band the track is painted in.
              height: markReserve - _markOverhang,
              child: markLabel == null
                  ? null
                  : CustomSingleChildLayout(
                      delegate: _MarkLabelLayout(
                        mark: mark,
                        gap: _labelGap - _markOverhang,
                      ),
                      child: Text(
                        markLabel!,
                        key: const Key('repereMarkLabel'),
                        maxLines: 1,
                        style: labelStyle,
                      ),
                    ),
            ),
          track,
        ],
      ),
    );
  }
}

/// Centres the mark's label over the [mark] position, kept inside the
/// meter's width, its bottom [gap] above the bottom of its box.
class _MarkLabelLayout extends SingleChildLayoutDelegate {
  const _MarkLabelLayout({required this.mark, required this.gap});

  final double mark;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (size.width * mark - childSize.width / 2).clamp(
      0.0,
      (size.width - childSize.width).clamp(0.0, double.infinity),
    );
    return Offset(left, size.height - childSize.height - gap);
  }

  @override
  bool shouldRelayout(_MarkLabelLayout oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.gap != gap;
}

/// The track, its fill and the mark, centred in a 12 px band (the mark's
/// height) so the mark stands on the track.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({
    required this.fraction,
    required this.fill,
    required this.track,
    required this.mark,
    required this.markColor,
  });

  final double fraction;
  final Color fill;
  final Color track;
  final double? mark;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(AppRadii.bar);
    final top = (size.height - RepereMeter.trackHeight) / 2;
    final rail = Rect.fromLTWH(0, top, size.width, RepereMeter.trackHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rail, radius),
      Paint()..color = track,
    );
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width * fraction, RepereMeter.trackHeight),
          radius,
        ),
        Paint()..color = fill,
      );
    }
    if (mark case final mark?) {
      final x = (size.width * mark).clamp(
        RepereMeter.markWidth / 2,
        size.width - RepereMeter.markWidth / 2,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: RepereMeter.markWidth,
          height: RepereMeter.markHeight,
        ),
        Paint()..color = markColor,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.fill != fill ||
      oldDelegate.track != track ||
      oldDelegate.mark != mark ||
      oldDelegate.markColor != markColor;
}
