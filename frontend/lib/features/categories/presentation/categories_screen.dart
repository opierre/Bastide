import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/presentation/rules_view.dart';
import '../application/categories_controller.dart';
import '../application/category_spend_controller.dart';
import '../domain/category.dart';
import '../domain/category_spend.dart';
import 'category_error_localizer.dart';
import 'category_form_modal.dart';
import 'category_row.dart';

/// The two-view management panel: the category tree, and the priority-ordered
/// rules that fill it in automatically (`docs/design/08-categories-rules.md`).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const path = '/categories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(categoriesViewProvider);

    return Padding(
      key: const Key('screen-categories'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 300,
                child: AppSegmented<CategoriesView>(
                  key: const Key('categoriesViewSwitch'),
                  value: view,
                  onChanged: (value) =>
                      ref.read(categoriesViewProvider.notifier).set(value),
                  segments: [
                    AppSegment(
                      key: const Key('categoriesViewSegment'),
                      value: CategoriesView.categories,
                      label: l10n.categoriesTabCategories,
                    ),
                    AppSegment(
                      key: const Key('rulesViewSegment'),
                      value: CategoriesView.rules,
                      label: l10n.categoriesTabRules,
                    ),
                  ],
                ),
              ),
              if (view == CategoriesView.rules) ...[
                const SizedBox(width: AppSpacing.lg),
                const Expanded(child: RulesViewHeaderActions()),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: switch (view) {
              CategoriesView.categories => const _CategoriesView(),
              CategoriesView.rules => const RulesView(),
            },
          ),
        ],
      ),
    );
  }
}

class _CategoriesView extends ConsumerWidget {
  const _CategoriesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tree = ref.watch(categoryTreeProvider);

    return switch (tree) {
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
    };
  }
}

/// The tree as one card of 41 px rows: a parent, then its subcategories
/// indented beneath it, separated by the card's quiet hairline.
class _CategoryTreeCard extends ConsumerWidget {
  const _CategoryTreeCard({required this.nodes});

  final List<CategoryNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spend = ref.watch(categorySpendProvider).value;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Which month the amounts and shares are for. Frame 08 draws the
          // columns without a caption, but the panel has no month picker of its
          // own, so without this line the figures are an amount of nothing in
          // particular — and the month is not always the calendar's current one.
          if (spend != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.categoriesSpendCaption(spend.month),
                key: const Key('categoriesSpendCaption'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ListView.separated(
            key: const Key('categoriesList'),
            shrinkWrap: true,
            itemCount: nodes.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, index) => _CategoryGroup(node: nodes[index], spend: spend),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({required this.node, required this.spend});

  final CategoryNode node;

  /// The month's spend, or `null` while it is loading — or after it failed. A
  /// summary the sidecar can't answer costs the panel its bars and nothing
  /// else: managing categories is what this screen is for, and it stays fully
  /// usable without the figures.
  final CategorySpendView? spend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CategoryRow(
          key: Key('categoryRow-${node.category.id}'),
          category: node.category,
          spend: spend?.forCategory(node.category.id),
          currency: spend?.currency,
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
            spend: spend?.forCategory(child.id),
            currency: spend?.currency,
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
