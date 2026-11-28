import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// A value that travels from its old value to its new one on the `measure`
/// clock (`00` §13): the one building block for figures, meters and bars.
///
/// The first build draws [value] where it is, without animating; a later
/// change travels from what is drawn now, so a change that interrupts
/// another lands on the newest value. Under reduced motion every change
/// lands at once.
class MeasureTween<T> extends StatelessWidget {
  const MeasureTween({
    super.key,
    required this.value,
    required this.builder,
    this.tween,
    this.child,
    this.onEnd,
  });

  /// Where the value is going.
  final T value;

  /// Draws the value as it is on this frame.
  final ValueWidgetBuilder<T> builder;

  /// Makes an empty tween of the right kind ([IntTween.new],
  /// [ColorTween.new], ...). The default [Tween] only interpolates types with
  /// `+`, `-` and `*` that stay in their type, such as [double] or [Offset];
  /// an [int] needs [IntTween].
  final Tween<T> Function()? tween;

  /// Passed to [builder] unchanged: a subtree that does not depend on the
  /// value.
  final Widget? child;

  /// Called when a change has finished travelling.
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final spec = MotionSpec.of(context);
    return TweenAnimationBuilder<T>(
      // `end` alone, and a fresh tween each build: on first build the tween
      // starts where it ends, so the value is drawn, not grown; later values
      // travel from the one on screen.
      tween: (tween?.call() ?? Tween<T>())..end = value,
      duration: spec.duration(MotionKind.measure),
      curve: spec.curve,
      onEnd: onEnd,
      builder: builder,
      child: child,
    );
  }
}
