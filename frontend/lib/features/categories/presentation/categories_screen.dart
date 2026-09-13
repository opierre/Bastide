import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../rules/application/rules_filter.dart';
import '../../rules/presentation/rules_view.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';
import 'category_card.dart';
import 'category_delete.dart';
import 'category_error_localizer.dart';
import 'category_form_modal.dart';

/// Cards per grid row (`docs/design/08`).
const int _gridColumns = 4;

/// The two-view management panel: the category taxonomy as a card grid, and
/// the priority-ordered rules that fill it in automatically
/// (`docs/design/08-categories-rules.md`).
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
                  onChanged: (value) {
                    // Switching by hand means "show me the view", not "the
                    // view as a card footer last narrowed it".
                    ref.read(rulesCategoryFilterProvider.notifier).set(null);
                    ref.read(categoriesViewProvider.notifier).set(value);
                  },
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
      AsyncData(:final value) => _CategoryGrid(nodes: value),
      AsyncError(:final error) => ErrorStateView(
        message: localizeCategoryError(l10n, error),
        messageKey: const Key('categoriesErrorText'),
        retryLabel: l10n.categoriesRetry,
        retryKey: const Key('categoriesRetryButton'),
        onRetry: () =>
            ref.read(categoriesControllerProvider.notifier).refresh(),
      ),
      _ => const Padding(
        key: Key('categoriesLoadingIndicator'),
        padding: EdgeInsets.only(top: AppSpacing.xs),
        child: _GridSkeleton(),
      ),
    };
  }
}

/// The 4-column grid, gap 18 — the grid gap the accounts and goals panels use.
///
/// Built as rows of four rather than a [GridView] for the reason the goals grid
/// gives: a card's height is its content's, and a fixed aspect ratio would clip
/// a category whose subcategories wrap to a third line.
class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.nodes});

  final List<CategoryNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleCounts = ref.watch(ruleCountsByCategoryProvider);

    Widget card(CategoryNode node) {
      final category = node.category;
      return CategoryCard(
        key: Key('categoryCard-${category.id}'),
        node: node,
        ruleCount: ruleCounts == null ? null : ruleCounts[category.id] ?? 0,
        onEdit: category.isSystem
            ? null
            : () => showCategoryForm(context, initial: category),
        onDelete: category.isSystem
            ? null
            : () => _delete(context, ref, category),
        onEditSubcategory: (child) => showCategoryForm(context, initial: child),
        onAddSubcategory: () => showCategoryForm(context, parent: category),
        onOpenRules: () {
          ref.read(rulesCategoryFilterProvider.notifier).set(category.id);
          ref.read(categoriesViewProvider.notifier).set(CategoriesView.rules);
        },
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < nodes.length; start += _gridColumns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.gridGap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < _gridColumns; column++) ...[
                if (column > 0) const SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  // A short last row leaves its slots empty rather than
                  // stretching its cards: a card wider than its neighbours
                  // reads as a different kind of thing.
                  child: start + column < nodes.length
                      ? card(nodes[start + column])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: const Key('categoriesGrid'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Two rows of card silhouettes, so the panel doesn't restructure when the
/// catalog lands.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => Row(
      children: [
        for (var column = 0; column < _gridColumns; column++) ...[
          if (column > 0) const SizedBox(width: AppSpacing.gridGap),
          const Expanded(child: SkeletonBlock(height: categoryCardMinHeight)),
        ],
      ],
    );

    return SkeletonPulse(
      child: Column(
        children: [
          row(),
          const SizedBox(height: AppSpacing.gridGap),
          row(),
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
  } catch (error) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizeCategoryError(l10n, error))));
  }
}
