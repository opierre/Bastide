import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';
import 'category_color.dart';

/// A parent category row: 41 px, swatch · name · ownership badge · trailing
/// affordances (`docs/design/08-categories-rules.md`).
///
/// The system/custom distinction is encoded three times over — badge text,
/// badge tint, and lock glyph vs ⋯ menu — because any one of them alone fails
/// somebody: the tint alone fails a colour-blind reader, and hiding the ⋯ alone
/// would leave a keyboard user no way to learn *why* nothing is offered. The
/// API's refusal to patch a system row is the fourth, and the only binding one.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;

  /// Both `null` for system categories — this widget never decides that; the
  /// screen does, from `isSystem`.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 41,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: categoryColor(category),
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Flexible(
            child: Text(
              localizedCategoryName(l10n, category.name),
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          if (category.isSystem)
            AppChip(key: const Key('categoryBadgeSystem'), label: l10n.categoryBadgeSystem)
          else
            AppChip(
              key: const Key('categoryBadgeCustom'),
              label: l10n.categoryBadgeCustom,
              color: AppColors.iris,
            ),
          const Spacer(),
          CategoryRowActions(
            category: category,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

/// A subcategory row: indented 30 px and set a step quieter, so the hierarchy
/// is carried by position and weight rather than by a tree line.
class CategorySubRow extends StatelessWidget {
  const CategorySubRow({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 41,
      child: Row(
        children: [
          const SizedBox(width: 30),
          Flexible(
            child: Text(
              localizedCategoryName(l10n, category.name),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const Spacer(),
          // A system subcategory carries no lock of its own: its parent row
          // already states the group is read-only, and a column of repeated
          // padlocks would read as six separate refusals instead of one.
          if (!category.isSystem)
            CategoryRowActions(
              category: category,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

/// The trailing pair: a lock on system rows, or delete + ⋯ on the user's own.
///
/// Delete is its own glyph rather than a second entry in the ⋯ menu because it
/// is the action a user reaches for by name — and keeping it visible means the
/// row's two outcomes, edit and remove, are both legible without opening
/// anything. It still asks for confirmation before it fires (see the screen).
class CategoryRowActions extends StatelessWidget {
  const CategoryRowActions({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (category.isSystem) {
      return Tooltip(
        message: l10n.categorySystemLockedTooltip,
        child: Icon(
          Icons.lock_outline_rounded,
          key: Key('categoryLock-${category.id}'),
          size: 16,
          color: AppColors.textDisabled,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('categoryDelete-${category.id}'),
          onPressed: onDelete,
          tooltip: l10n.categoryDelete,
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          color: AppColors.textSecondary,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        IconButton(
          key: Key('categoryEdit-${category.id}'),
          onPressed: onEdit,
          tooltip: l10n.categoryEdit,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          color: AppColors.textSecondary,
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    );
  }
}
