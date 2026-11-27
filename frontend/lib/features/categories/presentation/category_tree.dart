import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/application/rules_controller.dart';
import '../../rules/application/rules_filter.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';
import 'category_color.dart';
import 'category_delete.dart';
import 'category_error_localizer.dart';
import 'category_form_modal.dart';

/// The left pane of the categories panel (`docs/design/08` §Category tree):
/// « Catégories » and its `plus`, « Toutes les règles », one item per
/// top-level category with its subcategories under it when open, and the
/// note on system categories at the foot.
///
/// Selecting an item filters the rules pane: the selection is
/// [rulesCategoryFilterProvider], `null` for « Toutes les règles ».
class CategoryTree extends ConsumerWidget {
  const CategoryTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tree = ref.watch(categoryTreeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.categoriesTreeTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppButton(
                key: const Key('addCategoryButton'),
                label: l10n.categoriesAddButton,
                icon: LucideIcons300.plus,
                iconOnly: true,
                variant: AppButtonVariant.ghost,
                onPressed: () => showCategoryForm(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (tree) {
            AsyncData(:final value) when value.isEmpty => Center(
              child: Text(
                l10n.categoriesEmptyTitle,
                key: const Key('categoriesEmptyState'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            AsyncData(:final value) => _TreeList(nodes: value),
            AsyncError(:final error) => ErrorStateView(
              message: localizeCategoryError(l10n, error),
              messageKey: const Key('categoriesErrorText'),
              retryLabel: l10n.categoriesRetry,
              retryKey: const Key('categoriesRetryButton'),
              onRetry: () =>
                  ref.read(categoriesControllerProvider.notifier).refresh(),
            ),
            _ => const _TreeSkeleton(),
          },
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: NoteLine(
            key: const Key('categoriesSystemNote'),
            icon: LucideIcons300.lock,
            text: l10n.categoriesSystemNote,
          ),
        ),
      ],
    );
  }
}

class _TreeList extends ConsumerWidget {
  const _TreeList({required this.nodes});

  final List<CategoryNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(rulesCategoryFilterProvider);
    final expanded = ref.watch(expandedCategoriesProvider);
    final ruleCounts = ref.watch(ruleCountsByCategoryProvider);
    final totalRules = ref.watch(rulesControllerProvider).value?.length;
    final filter = ref.read(rulesCategoryFilterProvider.notifier);
    final expansion = ref.read(expandedCategoriesProvider.notifier);

    final items = <Widget>[
      _TreeItem(
        key: const Key('categoryTreeAll'),
        selected: selected == null,
        onTap: () => filter.set(null),
        label: l10n.categoriesAllRules,
        trailing: totalRules == null
            ? null
            : _CountText(label: l10n.categoryRuleCount(totalRules)),
      ),
    ];

    for (final node in nodes) {
      final category = node.category;
      final open = expanded.contains(category.id);
      final count = ruleCounts == null ? null : ruleCounts[category.id] ?? 0;
      items.add(
        _CategoryItem(
          key: Key('categoryTreeItem-${category.id}'),
          category: category,
          open: open,
          selected: selected == category.id,
          ruleCount: count,
          onTap: () {
            filter.set(category.id);
            expansion.expand(category.id);
          },
          onToggle: () => expansion.toggle(category.id),
          onEdit: () => showCategoryForm(context, initial: category),
          onDelete: () => _delete(context, ref, category),
        ),
      );
      if (!open) continue;
      final parentHue = categoryColor(context, category);
      for (final child in node.children) {
        items.add(
          _TreeItem(
            key: Key('categoryTreeSubitem-${child.id}'),
            indent: AppCategoriesPanel.subcategoryIndent,
            // Its own glyph in its main category's hue: the subcategory reads
            // as a member of that family without a dot of its own.
            leading: [
              Icon(
                categoryIcon(child),
                key: Key('categoryIcon-${child.id}'),
                color: parentHue,
              ),
            ],
            label: localizedCategoryName(l10n, child.name),
            // A system subcategory is inert; a custom one opens its form.
            onTap: child.isSystem
                ? null
                : () => showCategoryForm(context, initial: child),
          ),
        );
      }
      items.add(
        _TreeItem(
          key: Key('addSubcategory-${category.id}'),
          indent: AppCategoriesPanel.subcategoryIndent,
          muted: true,
          leading: const [Icon(LucideIcons300.plus)],
          label: l10n.categoryAddSubcategory,
          onTap: () => showCategoryForm(context, parent: category),
        ),
      );
    }

    return ListView.separated(
      key: const Key('categoryTree'),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxs),
      itemBuilder: (_, index) => items[index],
    );
  }
}

/// A top-level category: chevron, hue dot, icon, name and rule count; on
/// hover, a `lock` for a system category or the `ellipsis` menu for a custom
/// one.
class _CategoryItem extends StatefulWidget {
  const _CategoryItem({
    super.key,
    required this.category,
    required this.open,
    required this.selected,
    required this.ruleCount,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final bool open;
  final bool selected;

  /// `null` while the rules load: the item then states no count.
  final int? ruleCount;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  final _menu = MenuController();
  bool _hovered = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final category = widget.category;
    final count = widget.ruleCount;

    // Kept while the menu is open: the pointer has left the row for the menu.
    final showControl = _hovered || _menuOpen;
    final control = category.isSystem
        ? Tooltip(
            message: l10n.categorySystemLockedTooltip,
            child: Icon(
              LucideIcons300.lock,
              key: Key('categoryLock-${category.id}'),
              size: AppSizes.iconSmall,
              color: colors.textTertiary,
            ),
          )
        : MenuAnchor(
            controller: _menu,
            style: AppPopover.menuStyle(context),
            alignmentOffset: const Offset(0, AppSpacing.xs),
            onOpen: () => setState(() => _menuOpen = true),
            onClose: () => setState(() => _menuOpen = false),
            menuChildren: [
              AppMenuItem(
                key: Key('categoryEdit-${category.id}'),
                label: l10n.categoryEdit,
                onPressed: widget.onEdit,
              ),
              AppMenuItem(
                key: Key('categoryDelete-${category.id}'),
                label: l10n.categoryDelete,
                destructive: true,
                onPressed: widget.onDelete,
              ),
            ],
            child: AppButton(
              key: Key('categoryMenu-${category.id}'),
              label: l10n.categoryActionsTooltip,
              icon: LucideIcons300.ellipsis,
              iconOnly: true,
              variant: AppButtonVariant.ghost,
              onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _TreeItem(
        selected: widget.selected,
        onTap: widget.onTap,
        leading: [
          Semantics(
            button: true,
            expanded: widget.open,
            child: GestureDetector(
              key: Key('categoryTreeToggle-${category.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggle,
              child: Icon(
                widget.open
                    ? LucideIcons300.chevronDown
                    : LucideIcons300.chevronRight,
                color: colors.textTertiary,
              ),
            ),
          ),
          Container(
            key: Key('categoryDot-${category.id}'),
            width: CategoryLabel.dotSize,
            height: CategoryLabel.dotSize,
            decoration: BoxDecoration(
              color: categoryColor(context, category),
              borderRadius: BorderRadius.circular(AppRadii.bar),
            ),
          ),
          Icon(categoryIcon(category), key: Key('categoryIcon-${category.id}')),
        ],
        label: localizedCategoryName(l10n, category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              _CountText(
                key: Key('categoryRules-${category.id}'),
                label: l10n.categoryRuleCount(count),
                warning: count == 0,
              ),
            if (showControl) ...[
              const SizedBox(width: AppSpacing.xsPlus),
              control,
            ],
          ],
        ),
      ),
    );
  }
}

/// « 2 règles », 11 `textTertiary`; « aucune règle » in `warning`.
class _CountText extends StatelessWidget {
  const _CountText({super.key, required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: warning ? context.colors.warning : context.colors.textTertiary,
      ),
    );
  }
}

/// One item of the tree, on the nav-item recipe (`00` §5): 30 px, radius 6,
/// padding 0 8, 14 px icons 9 px apart, 13/400 `textSecondary`. Hover and
/// selected take the `hover` ground; selected also takes `text` at 500.
class _TreeItem extends StatefulWidget {
  const _TreeItem({
    super.key,
    required this.label,
    this.leading = const [],
    this.trailing,
    this.onTap,
    this.selected = false,
    this.muted = false,
    this.indent = AppSpacing.sm,
  });

  final String label;
  final List<Widget> leading;
  final Widget? trailing;

  /// `null` makes the item inert: no hover, no cursor.
  final VoidCallback? onTap;
  final bool selected;

  /// `textTertiary`, for « + Sous-catégorie ».
  final bool muted;

  /// The left padding; a subcategory is indented 52 px.
  final double indent;

  @override
  State<_TreeItem> createState() => _TreeItemState();
}

class _TreeItemState extends State<_TreeItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final interactive = widget.onTap != null;
    final foreground = widget.selected
        ? colors.text
        : (widget.muted ? colors.textTertiary : colors.textSecondary);
    final style =
        (widget.selected ? textTheme.labelLarge : textTheme.bodyMedium)
            ?.copyWith(color: foreground);

    final item = Container(
      height: AppSizes.navItem,
      padding: EdgeInsetsDirectional.only(
        start: widget.indent,
        end: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: widget.selected || (interactive && _hovered)
            ? colors.hover
            : null,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: IconTheme.merge(
        data: IconThemeData(size: AppSizes.iconSmall, color: foreground),
        child: Row(
          children: [
            for (final glyph in widget.leading) ...[
              glyph,
              const SizedBox(width: AppSpacing.navIconGap),
            ],
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );

    if (!interactive) return item;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: item,
        ),
      ),
    );
  }
}

/// The tree's silhouette while the catalog loads.
class _TreeSkeleton extends StatelessWidget {
  const _TreeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      key: const Key('categoriesLoadingIndicator'),
      child: Column(
        children: [
          for (var i = 0; i < 8; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xxs),
            const SkeletonBlock(height: AppSizes.navItem),
          ],
        ],
      ),
    );
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  AppCategory category,
) async {
  if (!await confirmCategoryDelete(context, category)) return;
  try {
    await ref.read(categoriesControllerProvider.notifier).delete(category.id);
    // The rules pane would otherwise stay filtered on a category that is gone.
    if (ref.read(rulesCategoryFilterProvider) == category.id) {
      ref.read(rulesCategoryFilterProvider.notifier).set(null);
    }
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(
      context,
      title: localizeCategoryError(AppLocalizations.of(context)!, error),
      tone: BannerTone.error,
    );
  }
}
