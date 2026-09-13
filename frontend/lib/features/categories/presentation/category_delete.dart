import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';

/// Asks before a category is deleted. Resolves `true` only on an explicit yes.
///
/// Deleting is not reversible and takes the subcategories with it, so the
/// question names the category and says so. Shared by the card's ⋯ menu and
/// the edit modal, which each handle the failure in their own place — a
/// snackbar under the panel, a banner inside the modal.
Future<bool> confirmCategoryDelete(
  BuildContext context,
  AppCategory category,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.categoryDeleteConfirmTitle),
      content: Text(
        l10n.categoryDeleteConfirmBody(
          localizedCategoryName(l10n, category.name),
        ),
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
  return confirmed ?? false;
}
