import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One choice offered by an [AppSelect].
@immutable
class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label, this.leading});

  final T value;
  final String label;

  /// Optional glyph shown before the label (an institution monogram, say).
  final Widget? leading;
}

/// The spec's select: a field-shaped anchor with an iris chevron plate, and an
/// overlay popover of 32px rows with an iris check on the selected one.
///
/// Built on [MenuAnchor] rather than [DropdownButtonFormField] for one reason
/// that matters to the user: Material's dropdown lays its menu *over* the
/// button, hiding the field the moment it opens, so the choice being changed
/// disappears. A menu anchor keeps the field visible and drops the options
/// beneath it, which is also what the design mockup draws.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.height = 44,
  });

  final T value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T> onChanged;
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

  /// Measures before opening so the popover can line up with the field it came
  /// from. Both the resize and the open land in the same frame, so the menu is
  /// never built against a stale width.
  void _toggle(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width;
    if (width != null && width != _menuWidth) setState(() => _menuWidth = width);
    controller.open();
  }

  @override
  Widget build(BuildContext context) {
    AppSelectItem<T>? selected;
    for (final item in widget.items) {
      if (item.value == widget.value) selected = item;
    }

    return MenuAnchor(
      onOpen: () => setState(() => _isOpen = true),
      onClose: () => setState(() => _isOpen = false),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceOverlay),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Color(0x66000000)),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        ),
        minimumSize: WidgetStatePropertyAll(Size(_menuWidth ?? 0, 0)),
        maximumSize: WidgetStatePropertyAll(
          Size(_menuWidth ?? double.infinity, 320),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.inset)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: [
        for (final item in widget.items)
          _Option<T>(
            item: item,
            isSelected: item.value == widget.value,
            onSelected: () => widget.onChanged(item.value),
          ),
      ],
      builder: (context, controller, _) => _Anchor(
        key: _anchorKey,
        label: selected?.label ?? '',
        leading: selected?.leading,
        height: widget.height,
        isOpen: _isOpen,
        onTap: () => _toggle(controller),
      ),
    );
  }
}

/// The closed state: a field well whose chevron sits on an iris plate, so the
/// control reads as *openable* rather than as a text input that happens to have
/// an arrow at its end.
class _Anchor extends StatelessWidget {
  const _Anchor({
    super.key,
    required this.label,
    required this.leading,
    required this.height,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final Widget? leading;
  final double height;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceField,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        hoverColor: AppColors.overlayWash,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.only(
            left: AppSpacing.sm + AppSpacing.xs,
            right: AppSpacing.sm - 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: isOpen ? AppColors.focusRing : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.irisSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(
                  isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 17,
                  color: AppColors.iris,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 32px option row. The selected one is marked by an iris check rather than
/// by a filled row: the popover sits on the overlay surface, where a full-width
/// fill would compete with hover.
class _Option<T> extends StatelessWidget {
  const _Option({
    required this.item,
    required this.isSelected,
    required this.onSelected,
  });

  final AppSelectItem<T> item;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onSelected,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs),
        ),
        overlayColor: const WidgetStatePropertyAll(AppColors.surfaceHover),
        foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
      ),
      child: Row(
        children: [
          if (item.leading != null) ...[
            item.leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? AppColors.iris : AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.check_rounded, size: 15, color: AppColors.iris),
          ],
        ],
      ),
    );
  }
}
