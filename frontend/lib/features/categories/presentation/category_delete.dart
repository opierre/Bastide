import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';

/// Asks before a category is deleted. Resolves `true` only on an explicit yes.
///
/// Deleting is not reversible and takes the subcategories with it, so the
/// question names the category and says so. Shared by the tree's menu and the
/// edit modal, which each handle the failure in their own place: a toast over
/// the panel, a banner inside the modal.
Future<bool> confirmCategoryDelete(
  BuildContext context,
  AppCategory category,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppModal(
      title: l10n.categoryDeleteConfirmTitle,
      width: AppCategoriesPanel.categoryFormWidth,
      actions: [
        AppButton(
          label: l10n.categoryFormCancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton(
          key: const Key('categoryDeleteConfirmButton'),
          label: l10n.categoryDelete,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
      child: Text(
        l10n.categoryDeleteConfirmBody(
          localizedCategoryName(l10n, category.name),
        ),
        style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
          color: dialogContext.colors.textSecondary,
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
