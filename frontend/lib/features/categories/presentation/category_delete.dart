import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';

/// Asks before a category is deleted. Resolves `true` only on an explicit yes.
///
/// Shared by the tree's menu and the edit modal, which each handle the
/// failure in their own place: a toast over the panel, a banner inside the
/// modal.
Future<bool> confirmCategoryDelete(
  BuildContext context,
  AppCategory category,
) async {
  final confirmed = await showAppModal<bool>(
    context: context,
    builder: (_) => CategoryDeleteModal(category: category),
  );
  return confirmed ?? false;
}

/// « Supprimer la catégorie « … » ? » (`08-categories-rules.md` §Other
/// modals, proposal v6 `m-categories`), 480 px: a destructive confirmation
/// without a body whose lead says the subcategories go too and their
/// transactions become uncategorized. Focus lands on « Annuler ».
class CategoryDeleteModal extends StatelessWidget {
  const CategoryDeleteModal({super.key, required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      key: const Key('categoryDeleteModal'),
      title: l10n.categoryDeleteConfirmTitle(
        localizedCategoryName(l10n, category.name),
      ),
      width: AppCategoriesPanel.categoryFormWidth,
      kind: AppModalKind.destructive,
      subtitle: Text(l10n.categoryDeleteConfirmLead),
      actions: [
        const AppModalCancel(key: Key('categoryDeleteCancel')),
        AppButton(
          key: const Key('categoryDeleteConfirmButton'),
          label: l10n.categoryDelete,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
