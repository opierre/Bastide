import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category.dart';
import 'category_color.dart';
import 'category_labels.dart';

/// The drawn floor of a card, so a category with no subcategories stands as
/// tall as its neighbours' shortest (`docs/design/08`).
const double categoryCardMinHeight = 196;

/// One top-level category as a card: header (icon tile · name · ownership
/// badge + kind · lock or ⋯), its subcategories as chips, and a footer naming
/// how many rules feed it (`docs/design/08-categories-rules.md`).
///
/// A taxonomy view, not a spending one: no amounts appear here — those live on
/// the dashboard's « Dépenses par catégorie » card.
///
/// The system/custom distinction is encoded three times over — badge text,
/// badge tint, and lock glyph vs ⋯ menu — because any one of them alone fails
/// somebody: the tint alone fails a colour-blind reader, and hiding the ⋯ alone
/// would leave a keyboard user no way to learn *why* nothing is offered. The
/// API's refusal to patch a system row is the fourth, and the only binding one.
///
/// The card itself takes no tap, so it has no hover: `docs/design/00` reserves
/// the iris hover border for cards that open something.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.node,
    required this.ruleCount,
    required this.onEdit,
    required this.onDelete,
    required this.onEditSubcategory,
    required this.onAddSubcategory,
    required this.onOpenRules,
  });

  final CategoryNode node;

  /// Rules targeting this category or its subcategories; `null` while the
  /// rules haven't loaded, when the footer states nothing rather than guess.
  final int? ruleCount;

  /// Both `null` for system categories — this widget never decides that; the
  /// screen does, from `isSystem`.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Opens a subcategory's edit modal. Only ever called for the user's own —
  /// a system chip is inert.
  final ValueChanged<AppCategory> onEditSubcategory;
  final VoidCallback onAddSubcategory;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) {
    final category = node.category;
    final hue = categoryColor(category);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: categoryCardMinHeight),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              category: category,
              hue: hue,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final child in node.children)
                  SubcategoryChip(
                    key: Key('subcategoryChip-${child.id}'),
                    category: child,
                    hue: hue,
                    onTap: child.isSystem
                        ? null
                        : () => onEditSubcategory(child),
                  ),
                _AddSubcategoryChip(
                  key: Key('addSubcategory-${category.id}'),
                  onTap: onAddSubcategory,
                ),
              ],
            ),
            // Pins the footer to the card's floor, so the footers of a row of
            // cards line up whatever each card's chips wrap to.
            const Spacer(),
            const SizedBox(height: AppSpacing.md),
            _Footer(
              categoryId: category.id,
              ruleCount: ruleCount,
              onOpenRules: onOpenRules,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.hue,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final Color hue;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(
            categoryIcon(category),
            key: Key('categoryIcon-${category.id}'),
            size: 18,
            color: hue,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedCategoryName(l10n, category.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Flexible(
                    child: category.isSystem
                        ? AppChip(
                            key: Key('categoryBadgeSystem-${category.id}'),
                            label: l10n.categoryBadgeSystem,
                          )
                        : AppChip(
                            key: Key('categoryBadgeCustom-${category.id}'),
                            label: l10n.categoryBadgeCustom,
                            color: AppColors.iris,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      categoryKindLabel(l10n, category.kind),
                      key: Key('categoryKind-${category.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.helper.copyWith(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (category.isSystem)
          SizedBox(
            width: 32,
            height: 32,
            child: Tooltip(
              message: l10n.categorySystemLockedTooltip,
              child: Icon(
                Icons.lock_outline_rounded,
                key: Key('categoryLock-${category.id}'),
                size: 16,
                color: AppColors.textDisabled,
              ),
            ),
          )
        else
          _ActionsMenu(category: category, onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

enum _CardAction { edit, delete }

/// The ⋯ on a user category: « Modifier » (name, icon, colour in one modal)
/// and « Supprimer », which confirms before it fires.
class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
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
      width: 32,
      height: 32,
      child: PopupMenuButton<_CardAction>(
        key: Key('categoryMenu-${category.id}'),
        tooltip: l10n.categoryActionsTooltip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: AppColors.textSecondary,
        ),
        position: PopupMenuPosition.under,
        onSelected: (action) => switch (action) {
          _CardAction.edit => onEdit?.call(),
          _CardAction.delete => onDelete?.call(),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            key: Key('categoryEdit-${category.id}'),
            value: _CardAction.edit,
            child: _MenuRow(
              icon: Icons.edit_outlined,
              label: l10n.categoryEdit,
            ),
          ),
          PopupMenuItem(
            key: Key('categoryDelete-${category.id}'),
            value: _CardAction.delete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l10n.categoryDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}

/// A subcategory as a 26 px chip: a swatch in the *parent's* hue, so the
/// family reads at a glance, and the name in the secondary ink.
///
/// A deliberately quieter shape than [CategoryChip] — neutral fill, no glyph —
/// because it is an entry in its parent's list, not a label on a transaction.
class SubcategoryChip extends StatelessWidget {
  const SubcategoryChip({
    super.key,
    required this.category,
    required this.hue,
    required this.onTap,
  });

  final AppCategory category;
  final Color hue;

  /// `null` on a system subcategory: the parent's lock already states the
  /// group is read-only, so the chip neither reacts nor repeats the padlock.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final chip = Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.borderSubtle,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              localizedCategoryName(l10n, category.name),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: tap, child: chip),
    );
  }
}

/// « + Sous-catégorie » — dashed ghost chip that opens the create modal with
/// this card's category preset as the parent. Iris on hover, the one colour
/// change that says it is an action rather than a missing entry.
class _AddSubcategoryChip extends StatefulWidget {
  const _AddSubcategoryChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddSubcategoryChip> createState() => _AddSubcategoryChipState();
}

class _AddSubcategoryChipState extends State<_AddSubcategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foreground = _hovered ? AppColors.iris : AppColors.textDisabled;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: DashedBorder(
          radius: 13,
          color: _hovered ? AppColors.iris : AppColors.borderDashed,
          child: SizedBox(
            height: 26,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 12, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                  // Flexible so a narrow window ellipsizes the label instead
                  // of overflowing the chip.
                  Flexible(
                    child: Text(
                      l10n.categoryAddSubcategory,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « N règles automatiques », linking to the rules view filtered on this
/// category. With no rule it reads « Aucune règle » in amber and links
/// nowhere — the filtered list would be empty.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.categoryId,
    required this.ruleCount,
    required this.onOpenRules,
  });

  final String categoryId;
  final int? ruleCount;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = ruleCount;
    final color = count == 0 ? AppColors.warning : AppColors.textDisabled;

    final line = Row(
      children: [
        Icon(Icons.play_arrow_rounded, size: 12, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            // Reserved as an empty line while the rules load, so the card
            // doesn't grow a row when they arrive.
            count == null ? '' : l10n.categoryRuleCount(count),
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.helper.copyWith(color: color),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        if (count == null || count == 0)
          KeyedSubtree(key: Key('categoryRules-$categoryId'), child: line)
        else
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: Key('categoryRules-$categoryId'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenRules,
              child: line,
            ),
          ),
      ],
    );
  }
}
