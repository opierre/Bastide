import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// Something that appears or leaves (`00` §13): it fades, and with [travel]
/// it also rises [distance] px as it comes in and sinks back as it goes.
/// Under reduced motion only the fade stays.
///
/// Two ways to drive it:
///
/// - On its own ([AppearTransition.new]): it fades in over `enter` when it is
///   first built while [visible], and in or out (`exit`, shorter) whenever
///   [visible] changes; [onHidden] runs once it is fully out. For overlays
///   that own their lifetime: toast, popover, menu.
/// - From an animation ([AppearTransition.driven]): a route's animation or
///   an [AnimatedSwitcher]'s, running linearly from 0 (out) to 1 (in). The
///   owner of that animation times it with
///   `MotionSpec.duration(MotionKind.appear)` and `MotionKind.leave`; this
///   widget applies the curve.
class AppearTransition extends StatefulWidget {
  const AppearTransition({
    super.key,
    this.visible = true,
    this.travel = true,
    this.onHidden,
    required this.child,
  }) : animation = null;

  const AppearTransition.driven({
    super.key,
    required Animation<double> this.animation,
    this.travel = true,
    required this.child,
  }) : visible = true,
       onHidden = null;

  /// Whether the child is shown. Changing it fades the child in or out.
  final bool visible;

  /// Whether the child rises [distance] px as it appears (and sinks back as
  /// it leaves), on top of the fade.
  final bool travel;

  /// Called once the child has fully left after [visible] turned false.
  final VoidCallback? onHidden;

  /// The external progress, for [AppearTransition.driven].
  final Animation<double>? animation;

  final Widget child;

  /// How far a surface travels as it appears or leaves.
  static const distance = 4.0;

  @override
  State<AppearTransition> createState() => _AppearTransitionState();
}

class _AppearTransitionState extends State<AppearTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  Animation<double> get _progress => widget.animation ?? _controller!;

  @override
  void initState() {
    super.initState();
    if (widget.animation == null) {
      _controller = AnimationController(
        vsync: this,
        // Flutter shortens a normal controller to almost nothing when the
        // platform disables animations; a fade stays under reduced motion
        // (`00` §13), so this one keeps its duration.
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener(_onStatus);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _controller;
    if (controller == null) return;
    final spec = MotionSpec.of(context);
    controller
      ..duration = spec.duration(MotionKind.appear)
      ..reverseDuration = spec.duration(MotionKind.leave);
    // First build: a visible child comes in.
    if (controller.isDismissed && widget.visible) controller.forward();
  }

  @override
  void didUpdateWidget(AppearTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      (oldWidget.animation == null) == (widget.animation == null),
      'An AppearTransition cannot switch between driving itself and being '
      'driven.',
    );
    final controller = _controller;
    if (controller == null || oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && !widget.visible) widget.onHidden?.call();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = MotionSpec.of(context);
    final eased = _progress.drive(CurveTween(curve: spec.curve));
    final rise = widget.travel ? spec.travel(AppearTransition.distance) : 0.0;
    // The same tree with or without travel, so turning reduced motion on
    // keeps the child's state.
    return AnimatedBuilder(
      animation: eased,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, rise * (1 - eased.value)),
        child: child,
      ),
      child: FadeTransition(opacity: eased, child: widget.child),
    );
  }
}
