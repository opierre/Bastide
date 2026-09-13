import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transactions_controller.dart';
import '../../categories/domain/category.dart' show AppCategory;
import '../domain/transaction.dart';
import 'transaction_error_localizer.dart';

/// Opens the category picker popover anchored under [anchorContext]'s widget
/// — a 250px overlay with a search field and the category catalog, the
/// current category checked (see `docs/design/07-transactions.md`).
///
/// Assigning only. "Toujours catégoriser ainsi" is a rule form of its own
/// (`always_categorize_modal.dart`), because a rule needs a field, a condition
/// and a pattern the user can see and change — a category tap alone can't say
/// what the rule would match.
Future<void> showCategoryPicker(
  BuildContext anchorContext,
  WidgetRef ref, {
  required Transaction transaction,
}) async {
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(
        Offset(0, button.size.height + 4),
        ancestor: overlay,
      ),
      button.localToGlobal(
        button.size.bottomRight(const Offset(0, 4)),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  await showMenu<void>(
    context: anchorContext,
    position: position,
    color: AppColors.surfaceOverlay,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      side: const BorderSide(color: AppColors.border),
    ),
    constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: _CategoryPickerBody(transaction: transaction),
      ),
    ],
  );
}

class _CategoryPickerBody extends ConsumerStatefulWidget {
  const _CategoryPickerBody({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_CategoryPickerBody> createState() =>
      _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends ConsumerState<_CategoryPickerBody> {
  String _query = '';
  bool _isSaving = false;

  Future<void> _select(String categoryId) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(transactionsControllerProvider.notifier);
    try {
      await notifier.updateCategory(widget.transaction, categoryId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeTransactionError(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(transactionCategoriesProvider);

    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: TextField(
              key: const Key('categoryPickerSearchField'),
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.categoryPickerSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                filled: true,
                fillColor: AppColors.surfaceField,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: switch (categoriesAsync) {
              AsyncData(:final value) => _CategoryList(
                categories: _filter(value, _query),
                currentCategoryId: widget.transaction.category?.id,
                isSaving: _isSaving,
                onSelect: _select,
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l10n.categoryPickerLoadError,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            },
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  List<AppCategory> _filter(List<AppCategory> categories, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return categories;
    final l10n = AppLocalizations.of(context)!;
    return categories
        .where(
          (category) => localizedCategoryName(
            l10n,
            category.name,
          ).toLowerCase().contains(needle),
        )
        .toList();
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.currentCategoryId,
    required this.isSaving,
    required this.onSelect,
  });

  final List<AppCategory> categories;
  final String? currentCategoryId;
  final bool isSaving;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          l10n.categoryPickerEmpty,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      key: const Key('categoryPickerList'),
      shrinkWrap: true,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = category.id == currentCategoryId;
        final slug = categorySlugFor(name: category.name, kind: category.kind);

        return InkWell(
          key: Key('categoryPickerItem-${category.id}'),
          onTap: isSaving ? null : () => onSelect(category.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm - 2,
            ),
            child: Row(
              children: [
                Icon(
                  CategoryIcons.forSlug(slug),
                  size: 14,
                  color: CategoryHues.forSlug(slug),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    localizedCategoryName(l10n, category.name),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.iris,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
