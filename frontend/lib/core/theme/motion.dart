import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// What a timed change is, which decides its duration (`00` §13).
enum MotionKind {
  /// Something appears: a fade, with or without travel, over `enter`.
  appear,

  /// Something leaves: a fade, with or without travel, over `exit`.
  leave,

  /// A toggle's knob slides, over `toggle`.
  toggle,

  /// A selection moves (segment thumb, tab underline, sidebar width), over
  /// `move`.
  move,

  /// A value changes (figure, meter fill, chart bars), over `measure`.
  measure,
}

/// The one place that resolves motion for a widget: each kind's duration and
/// curve, with the reduced-motion split of `00` §13 applied.
///
/// Under the OS « reduce motion » setting, travel, growth and counting are 0
/// (figures, meters and bars land at once, thumbs and knobs jump) while fades
/// stay, so an appearing or leaving surface is still announced; the loading
/// silhouette stops pulsing.
///
/// No widget reads the reduce-motion setting itself or names a curve: it asks
/// `MotionSpec.of(context)`.
@immutable
final class MotionSpec {
  const MotionSpec({this.reduced = false});

  /// The spec for [context]: reduced when the platform asks animations to be
  /// disabled.
  factory MotionSpec.of(BuildContext context) => MotionSpec(
    reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
  );

  /// The OS « reduce motion » setting is on.
  final bool reduced;

  /// How long a change of [kind] takes; [Duration.zero] when it lands at once.
  Duration duration(MotionKind kind) => switch (kind) {
    // Fades stay under reduced motion.
    MotionKind.appear => AppMotion.enter,
    MotionKind.leave => AppMotion.exit,
    MotionKind.toggle => reduced ? Duration.zero : AppMotion.toggle,
    MotionKind.move => reduced ? Duration.zero : AppMotion.move,
    MotionKind.measure => reduced ? Duration.zero : AppMotion.measure,
  };

  /// The curve of every timed change.
  Curve get curve => AppMotion.curve;

  /// How far something that appears travels, given the distance it would
  /// travel with full motion: 0 under reduced motion, where only the fade
  /// stays.
  double travel(double distance) => reduced ? 0 : distance;

  /// Whether the loading silhouette pulses.
  bool get pulses => !reduced;

  /// One full pulse of the loading silhouette, there and back.
  Duration get shimmer => AppMotion.shimmer;

  /// The pulse is a loop, not a change from one value to another, so it
  /// breathes symmetrically rather than on the ease-out [curve].
  Curve get pulseCurve => Curves.easeInOut;

  @override
  bool operator ==(Object other) =>
      other is MotionSpec && other.reduced == reduced;

  @override
  int get hashCode => reduced.hashCode;
}
