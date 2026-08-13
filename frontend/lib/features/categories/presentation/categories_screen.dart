import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';
import 'category_error_localizer.dart';
import 'category_form_modal.dart';
import 'category_row.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const path = '/categories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tree = ref.watch(categoryTreeProvider);

    return Padding(
      key: const Key('screen-categories'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: switch (tree) {
        AsyncData(:final value) when value.isEmpty => EmptyStateView(
          key: const Key('categoriesEmptyState'),
          icon: Icons.donut_small_outlined,
          title: l10n.categoriesEmptyTitle,
          message: l10n.categoriesEmptyBody,
          action: PrimaryButton(
            key: const Key('emptyStateAddCategoryButton'),
            label: l10n.categoriesAddButton,
            icon: Icons.add_rounded,
            height: 44,
            onPressed: () => showCategoryForm(context),
          ),
        ),
        AsyncData(:final value) => _CategoryTreeCard(nodes: value),
        AsyncError(:final error) => ErrorStateView(
          message: localizeCategoryError(l10n, error),
          messageKey: const Key('categoriesErrorText'),
          retryLabel: l10n.categoriesRetry,
          retryKey: const Key('categoriesRetryButton'),
          onRetry: () => ref.read(categoriesControllerProvider.notifier).refresh(),
        ),
        _ => const Padding(
          key: Key('categoriesLoadingIndicator'),
          padding: EdgeInsets.only(top: 24),
          child: SkeletonList(itemHeight: 41),
        ),
      },
    );
  }
}

/// The tree as one card of 41 px rows: a parent, then its subcategories
/// indented beneath it, separated by the card's quiet hairline.
class _CategoryTreeCard extends ConsumerWidget {
  const _CategoryTreeCard({required this.nodes});

  final List<CategoryNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: ListView.separated(
        key: const Key('categoriesList'),
        shrinkWrap: true,
        itemCount: nodes.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.borderSubtle,
        ),
        itemBuilder: (context, index) => _CategoryGroup(node: nodes[index]),
      ),
    );
  }
}

class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({required this.node});

  final CategoryNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CategoryRow(
          key: Key('categoryRow-${node.category.id}'),
          category: node.category,
          onEdit: node.category.isSystem
              ? null
              : () => showCategoryForm(context, initial: node.category),
          onDelete: node.category.isSystem
              ? null
              : () => _confirmDelete(context, ref, node.category),
        ),
        for (final child in node.children)
          CategorySubRow(
            key: Key('categoryRow-${child.id}'),
            category: child,
            onEdit: child.isSystem ? null : () => showCategoryForm(context, initial: child),
            onDelete: child.isSystem ? null : () => _confirmDelete(context, ref, child),
          ),
      ],
    );
  }
}

/// Deleting a category is not reversible and takes its subcategories with it,
/// so it asks first — and says which of the two is about to happen.
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  AppCategory category,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.categoryDeleteConfirmTitle),
      content: Text(
        l10n.categoryDeleteConfirmBody(localizedCategoryName(l10n, category.name)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.categoryFormCancel),
        ),
        FilledButton(
          key: const Key('categoryDeleteConfirmButton'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.categoryDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(categoriesControllerProvider.notifier).delete(category.id);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizeCategoryError(l10n, error))));
  }
}
