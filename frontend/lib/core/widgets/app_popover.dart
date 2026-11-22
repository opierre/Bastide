import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/tokens.dart';

/// The popover and menu of `docs/design/00-design-system.md` §7: `surface`,
/// 1 px `lineStrong`, radius 8, `shadow`, padding 4; items 28 px, radius 4,
/// `hover` on hover, a 14 px `check` on the selected one.
///
/// Two halves, because Flutter draws menus two ways: [AppPopover.menuStyle]
/// dresses a [MenuAnchor] (the select, overflow menus), and [AppPopover]
/// itself is the box for a popover a widget lays out on its own.
class AppPopover extends StatelessWidget {
  const AppPopover({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  /// The [MenuStyle] of a [MenuAnchor] menu. A [MenuStyle] takes an elevation
  /// rather than a [BoxShadow] list, so the shadow is the nearest Material
  /// elevation in the `shadow` token's colour.
  static MenuStyle menuStyle(BuildContext context, {double maxHeight = 320}) {
    final colors = context.colors;
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colors.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(colors.shadow.first.color),
      elevation: const WidgetStatePropertyAll(AppShadows.popoverElevation),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.xs)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, maxHeight)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.container),
          ),
          side: BorderSide(color: colors.lineStrong),
        ),
      ),
    );
  }

  /// The box itself, for a popover drawn outside a [MenuAnchor].
  static BoxDecoration decoration(AppColors colors) => BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(AppRadii.container),
    border: Border.all(color: colors.lineStrong),
    boxShadow: colors.shadow,
  );

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(AppSpacing.xs),
    decoration: decoration(context.colors),
    child: child,
  );
}

/// One 28 px row of a [MenuAnchor] menu dressed by [AppPopover.menuStyle].
/// It is a [MenuItemButton], so the menu's keyboard navigation reaches it.
class AppMenuItem extends StatelessWidget {
  const AppMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.leading,
    this.subtitle,
    this.detail,
    this.mono = false,
    this.width,
    this.destructive = false,
  });

  final String label;

  /// `null` disables the item.
  final VoidCallback? onPressed;

  /// Draws the trailing `check`.
  final bool selected;

  /// A 14 px icon or a small monogram before the label.
  final Widget? leading;

  /// A second line, for a choice that needs one (a property's address).
  final String? subtitle;

  /// Text after the label in `textTertiary` (a transaction's date and amount).
  final String? detail;

  /// Sets the label in Geist Mono: a raw bank label.
  final bool mono;

  /// The row's width; a [MenuAnchor] panel sizes itself to its widest row, so
  /// giving every row the anchor's width lines the menu up with its field.
  final double? width;

  /// `negative` label, for « Supprimer » in an overflow menu.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final foreground = destructive ? colors.negative : colors.text;

    return SizedBox(
      width: width,
      child: MenuItemButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.popoverItem),
          ),
          // Desktop rows: no padded touch target, no density adjustment.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.item)),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? colors.hover
                : Colors.transparent,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(foreground),
          iconColor: WidgetStatePropertyAll(colors.textSecondary),
          iconSize: const WidgetStatePropertyAll(AppSizes.iconSmall),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            // A menu button lays its child out at unbounded width, so the
            // label only fills the row when the row has a width to fill.
            Flexible(
              fit: width == null ? FlexFit.loose : FlexFit.tight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: subtitle == null ? 0 : AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSelectLabel(
                      label: label,
                      detail: detail,
                      mono: mono,
                      color: foreground,
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                LucideIcons300.check,
                key: const Key('appMenuItemCheck'),
                size: AppSizes.iconSmall,
                color: colors.text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A choice's label on one line, ellipsized: in Geist Mono when [mono] (a
/// raw bank label), then [detail] 6 px after it in `textTertiary`. Shared by
/// the closed [AppMenuItem] row and the closed select.
class AppSelectLabel extends StatelessWidget {
  const AppSelectLabel({
    super.key,
    required this.label,
    this.detail,
    this.mono = false,
    this.color,
  });

  final String label;
  final String? detail;
  final bool mono;

  /// The label's colour; `text` by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = Theme.of(context).textTheme.bodyMedium;
    final labelStyle = (mono ? context.textStyles.mono : body)?.copyWith(
      color: color ?? colors.text,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label, style: labelStyle),
          if (detail case final detail?) ...[
            const WidgetSpan(child: SizedBox(width: AppSpacing.xsPlus)),
            TextSpan(
              text: detail,
              style: body?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: body,
    );
  }
}
