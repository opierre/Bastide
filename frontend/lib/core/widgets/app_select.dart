import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';
import 'app_popover.dart';
import 'focus_ring.dart';

/// One choice offered by an [AppSelect].
@immutable
class AppSelectItem<T> {
  const AppSelectItem({
    required this.value,
    required this.label,
    this.leading,
    this.subtitle,
    this.detail,
    this.mono = false,
  });

  final T value;
  final String label;

  /// Optional text after the label, in `textTertiary`, both in the closed
  /// field and in the menu (a transaction's date and amount, say).
  final String? detail;

  /// Sets the label in Geist Mono: a raw bank label (`00` §3).
  final bool mono;

  /// Optional secondary line under the label in the open menu only (a
  /// property's address, say); the closed field states the label alone.
  final String? subtitle;

  /// Optional glyph shown before the label (an institution monogram, say).
  final Widget? leading;
}

/// The select of `docs/design/00-design-system.md` §6: the field look with a
/// trailing 14 px `chevron-down` in `textTertiary`, 32 px in a form and 28 px
/// in a toolbar ([AppSelect.toolbar]). It opens an [AppPopover] menu as wide
/// as the field, with a `check` on the current choice.
///
/// Built on [MenuAnchor] rather than [DropdownButtonFormField]: Material's
/// dropdown lays its menu over the button and hides the choice being
/// changed; a menu anchor keeps the field visible and drops the options
/// beneath it.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.height = AppSizes.formField,
  });

  /// The 28 px select of a toolbar or the title bar.
  const AppSelect.toolbar({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : height = AppSizes.toolbarSelect;

  final T value;
  final List<AppSelectItem<T>> items;

  /// `null` disables the select.
  final ValueChanged<T>? onChanged;
  final double height;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final _anchorKey = GlobalKey();
  bool _isOpen = false;

  /// The anchor's width, measured off the laid-out field rather than read from
  /// a [LayoutBuilder]: the imports panel measures its cards with an
  /// [IntrinsicHeight], and a layout builder cannot answer an intrinsic query.
  double? _menuWidth;

  /// Measures before opening so the popover lines up with the field it came
  /// from. Both the resize and the open land in the same frame, so the menu is
  /// never built against a stale width.
  void _toggle(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width;
    if (width != null && width != _menuWidth) {
      setState(() => _menuWidth = width);
    }
    controller.open();
  }

  @override
  Widget build(BuildContext context) {
    AppSelectItem<T>? selected;
    for (final item in widget.items) {
      if (item.value == widget.value) selected = item;
    }
    final onChanged = widget.onChanged;
    // A row is the field's width less the popover's padding on either side,
    // so the popover's outer edge lines up with the field's.
    final rowWidth = _menuWidth == null
        ? null
        : _menuWidth! - AppSpacing.xs * 2;

    return MenuAnchor(
      onOpen: () => setState(() => _isOpen = true),
      onClose: () => setState(() => _isOpen = false),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: AppPopover.menuStyle(context),
      menuChildren: [
        for (final item in widget.items)
          AppMenuItem(
            label: item.label,
            subtitle: item.subtitle,
            detail: item.detail,
            mono: item.mono,
            leading: item.leading,
            width: rowWidth,
            selected: item.value == widget.value,
            onPressed: onChanged == null ? null : () => onChanged(item.value),
          ),
      ],
      builder: (context, controller, _) => _Anchor(
        key: _anchorKey,
        label: selected?.label ?? '',
        detail: selected?.detail,
        mono: selected?.mono ?? false,
        leading: selected?.leading,
        height: widget.height,
        isOpen: _isOpen,
        onTap: onChanged == null ? null : () => _toggle(controller),
      ),
    );
  }
}

/// The closed select: a field well with the chevron at its end.
class _Anchor extends StatefulWidget {
  const _Anchor({
    super.key,
    required this.label,
    required this.detail,
    required this.mono,
    required this.leading,
    required this.height,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final bool mono;
  final Widget? leading;
  final double height;
  final bool isOpen;
  final VoidCallback? onTap;

  @override
  State<_Anchor> createState() => _AnchorState();
}

class _AnchorState extends State<_Anchor> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onTap != null;

    final field = Container(
      height: widget.height,
      padding: const EdgeInsets.only(
        left: AppSpacing.sm + AppSpacing.xxs,
        right: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _hovered && enabled ? colors.hover : colors.field,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: widget.isOpen ? colors.accent : colors.lineStrong,
        ),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AppSelectLabel(
              label: widget.label,
              detail: widget.detail,
              mono: widget.mono,
            ),
          ),
          const SizedBox(width: AppSpacing.xsPlus),
          Icon(
            LucideIcons300.chevronDown,
            size: AppSizes.iconSmall,
            color: colors.textTertiary,
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
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
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: FocusRing(
              focused: _focused,
              radius: AppRadii.control,
              child: field,
            ),
          ),
        ),
      ),
    );
  }
}
