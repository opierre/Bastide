import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'focus_ring.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.key});

  final T value;
  final String label;
  final Key? key;
}

/// The segmented control of `docs/design/00-design-system.md` §6: a `field`
/// well with a 1 px `lineStrong` border, radius 6, padding 2, gap 2; each
/// segment padding 2 10, radius 4, 13 `textSecondary`; the selected one on
/// `hover`, in `text` 500.
///
/// For two or three fixed options where one is always selected; a chip would
/// read as a filter the user can clear.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.height,
  });

  final List<AppSegment<T>> segments;
  final T value;

  /// `null` disables the control.
  final ValueChanged<T>? onChanged;

  /// Shares the width it is given between the segments instead of sizing
  /// each to its label.
  final bool expand;

  /// Pins the whole control to this height, the label centred in each
  /// segment. The title bar passes [AppSizes.button] so the control matches
  /// its other 28 px contextual controls (`00` §5): its 48 px height would
  /// otherwise stretch the segments. `null` sizes the control to its labels.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final children = <Widget>[
      for (var i = 0; i < segments.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.xxs),
        _wrap(
          _Segment(
            key: segments[i].key,
            label: segments[i].label,
            selected: segments[i].value == value,
            compact: height != null,
            onTap: onChanged == null
                ? null
                : () => onChanged(segments[i].value),
          ),
        ),
      ],
    ];

    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: context.colors.field,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: context.colors.lineStrong),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  /// Sized to its label, but shrinking (and ellipsizing) when the control is
  /// given less room than its labels ask for.
  Widget _wrap(Widget segment) =>
      expand ? Expanded(child: segment) : Flexible(child: segment);
}

class _Segment extends StatefulWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// The control's height is fixed: the segment fills it and drops its
  /// vertical padding, so the label stays centred without overflowing.
  final bool compact;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // Selection is an instant fill swap (`00` §13).
          child: FocusRing(
            focused: _focused,
            radius: AppRadii.item,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xxs,
                vertical: widget.compact ? 0 : AppSpacing.xxs,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected ? colors.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.item),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.selected ? colors.text : colors.textSecondary,
                  fontWeight: widget.selected
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
