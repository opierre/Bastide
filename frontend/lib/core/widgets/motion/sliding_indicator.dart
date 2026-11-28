import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// A selection mark (a segment's thumb, a tab's underline, a toggle's knob)
/// painted at the selected slot, which slides to the next slot when the
/// selection moves (`00` §13), over `toggle` or `move` as [kind] says.
///
/// The caller lays out its own row and marks each slot with a
/// [SlidingIndicatorSlot]; the mark is painted behind [child], over the
/// selected slot's box (or the part of it [shape] picks), with [decoration].
/// It is drawn in place on first paint, follows a resize at once, and jumps
/// under reduced motion. The labels are the caller's: they change state at
/// once.
class SlidingIndicator extends StatefulWidget {
  const SlidingIndicator({
    super.key,
    required this.selected,
    required this.decoration,
    required this.child,
    this.kind = MotionKind.move,
    this.shape,
  }) : assert(
         kind == MotionKind.move || kind == MotionKind.toggle,
         'A selection slides over `move` or `toggle`.',
       );

  /// The index of the selected [SlidingIndicatorSlot]; no mark when null.
  final int? selected;

  /// How the mark is painted.
  final Decoration decoration;

  /// [MotionKind.toggle] for a knob, [MotionKind.move] for a thumb or an
  /// underline.
  final MotionKind kind;

  /// The mark's box within the selected slot's box, in this widget's
  /// coordinates: the bottom 2 px for an underline. The whole slot when null.
  final Rect Function(Rect slot)? shape;

  /// The row that holds the slots.
  final Widget child;

  @override
  State<SlidingIndicator> createState() => _SlidingIndicatorState();
}

class _SlidingIndicatorState extends State<SlidingIndicator>
    with SingleTickerProviderStateMixin {
  // At rest at 1: the mark sits on its slot.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.duration = MotionSpec.of(context).duration(widget.kind);
  }

  @override
  void didUpdateWidget(SlidingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress.duration = MotionSpec.of(context).duration(widget.kind);
  }

  /// The render object asks for a new run when the selection moves, while
  /// the tree is built, so the run starts on this frame.
  void _restart() => _progress.forward(from: 0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = MotionSpec.of(context);
    return _SlidingIndicatorBox(
      selected: widget.selected,
      decoration: widget.decoration,
      shape: widget.shape,
      progress: _progress,
      curve: spec.curve,
      animates: spec.duration(widget.kind) > Duration.zero,
      onRestart: _restart,
      textDirection: Directionality.maybeOf(context),
      child: widget.child,
    );
  }
}

/// Marks one slot of the nearest [SlidingIndicator] above it.
class SlidingIndicatorSlot extends SingleChildRenderObjectWidget {
  const SlidingIndicatorSlot({super.key, required this.index, super.child});

  /// The slot's position, matched against [SlidingIndicator.selected].
  final int index;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSlot(index);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSlot).index = index;
  }
}

class _SlidingIndicatorBox extends SingleChildRenderObjectWidget {
  const _SlidingIndicatorBox({
    required this.selected,
    required this.decoration,
    required this.shape,
    required this.progress,
    required this.curve,
    required this.animates,
    required this.onRestart,
    required this.textDirection,
    super.child,
  });

  final int? selected;
  final Decoration decoration;
  final Rect Function(Rect slot)? shape;
  final Animation<double> progress;
  final Curve curve;
  final bool animates;
  final VoidCallback onRestart;
  final TextDirection? textDirection;

  @override
  _RenderSlidingIndicator createRenderObject(BuildContext context) =>
      _RenderSlidingIndicator(
        selected: selected,
        decoration: decoration,
        shape: shape,
        progress: progress,
        curve: curve,
        animates: animates,
        onRestart: onRestart,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlidingIndicator renderObject,
  ) {
    // The selection last: moving it reads the others.
    renderObject
      ..decoration = decoration
      ..shape = shape
      ..progress = progress
      ..curve = curve
      ..animates = animates
      ..onRestart = onRestart
      ..textDirection = textDirection
      ..selected = selected;
  }
}

class _RenderSlidingIndicator extends RenderProxyBox {
  _RenderSlidingIndicator({
    required this._selected,
    required this._decoration,
    required this.shape,
    required this._progress,
    required this.curve,
    required this.animates,
    required this.onRestart,
    required this._textDirection,
  });

  final Map<int, _RenderSlot> _slots = {};

  Rect Function(Rect slot)? shape;
  Curve curve;
  bool animates;
  VoidCallback onRestart;

  int? _selected;
  set selected(int? value) {
    if (value == _selected) return;
    // Slide from wherever the mark is now, which is mid-way when this
    // interrupts another slide; the paint resolves where it slides to.
    _from = _current;
    _selected = value;
    _moved = true;
    if (animates && _from != null) onRestart();
    markNeedsPaint();
  }

  Decoration _decoration;
  set decoration(Decoration value) {
    if (value == _decoration) return;
    _decoration = value;
    _painter?.dispose();
    _painter = null;
    markNeedsPaint();
  }

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(_onTick);
    _progress = value;
    if (attached) _progress.addListener(_onTick);
  }

  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  // Where the mark slides from and to.
  Rect? _from;
  Rect? _to;

  /// The selection has moved since the last paint.
  bool _moved = false;

  void _register(_RenderSlot slot) {
    _slots[slot.index] = slot;
    if (attached) markNeedsPaint();
  }

  void _unregister(_RenderSlot slot, int index) {
    if (_slots[index] == slot) _slots.remove(index);
    if (attached) markNeedsPaint();
  }

  void _onTick() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(_onTick);
  }

  @override
  void detach() {
    _progress.removeListener(_onTick);
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }

  /// The selected slot's box in this box's coordinates.
  Rect? _target() {
    final slot = _slots[_selected];
    if (slot == null || !slot.attached || !slot.hasSize) return null;
    return MatrixUtils.transformRect(
      slot.getTransformTo(this),
      Offset.zero & slot.size,
    );
  }

  Rect? get _current {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return to;
    return Rect.lerp(from, to, curve.transform(_progress.value));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final target = _target();
    if (target == null) {
      _from = _to = null;
    } else if (_moved) {
      _to = target;
      // Nothing to slide from, or reduced motion: the mark lands at once.
      if (!animates || _from == null) _from = target;
    } else if (target != _to) {
      // Same selection, new layout: follow it, at once when at rest.
      if (!_progress.isAnimating || _from == null) _from = target;
      _to = target;
    }
    _moved = false;

    if (_current case final slot?) {
      final mark = shape?.call(slot) ?? slot;
      final painter = _painter ??= _decoration.createBoxPainter(markNeedsPaint);
      painter.paint(
        context.canvas,
        offset + mark.topLeft,
        ImageConfiguration(size: mark.size, textDirection: _textDirection),
      );
    }
    super.paint(context, offset);
  }
}

class _RenderSlot extends RenderProxyBox {
  _RenderSlot(this._index);

  _RenderSlidingIndicator? _host;

  int _index;
  int get index => _index;
  set index(int value) {
    if (value == _index) return;
    final old = _index;
    _index = value;
    _host
      ?.._unregister(this, old)
      .._register(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    var node = parent;
    while (node != null && node is! _RenderSlidingIndicator) {
      node = node.parent;
    }
    _host = node as _RenderSlidingIndicator?;
    _host?._register(this);
  }

  @override
  void detach() {
    _host?._unregister(this, _index);
    _host = null;
    super.detach();
  }
}
