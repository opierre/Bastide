import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_color.dart';
import '../domain/rule.dart';
import 'rule_labels.dart';

/// The columns of the rules table (`docs/design/08` §Rules pane). The table
/// runs edge to edge, so its first and last cells sit 32 px in: an empty
/// column on each side makes up the difference with the 12 px cell gap.
List<AppTableColumn> ruleTableColumns(AppLocalizations l10n) => [
  const AppTableColumn(label: '', width: AppSpacing.xl - AppSpacing.smPlus),
  AppTableColumn(
    label: l10n.rulesColumnOrder,
    width: AppCategoriesPanel.orderColumn,
  ),
  AppTableColumn(label: l10n.rulesColumnField, flex: 2),
  AppTableColumn(label: l10n.rulesColumnCondition, flex: 2),
  AppTableColumn(label: l10n.rulesColumnPattern, flex: 4),
  AppTableColumn(label: l10n.rulesColumnCategory, flex: 4),
  AppTableColumn(
    label: l10n.rulesColumnMatches,
    width: AppCategoriesPanel.matchesColumn,
    numeric: true,
  ),
  AppTableColumn(
    label: l10n.rulesColumnActive,
    width: AppCategoriesPanel.activeColumn,
    numeric: true,
  ),
  const AppTableColumn(label: '', width: AppSpacing.xl - 2 * AppSpacing.smPlus),
];

/// One rule as a row of the rules table: grip and position, field,
/// condition, pattern, target category, match count and toggle.
///
/// A disabled rule's row is dimmed and its toggle off; the toggle stays
/// reachable, which is the point of showing a disabled rule at all. A tap on
/// the row opens the rule editor.
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.rule,
    required this.columns,
    required this.position,
    required this.category,
    required this.parent,
    required this.matchCount,
    required this.index,
    required this.onEdit,
    required this.onToggle,
    this.canReorder = true,
  });

  final Rule rule;
  final List<AppTableColumn> columns;

  /// The rule's place in the evaluation order, from 1.
  final int position;

  /// The rule's target. `null` when the catalog hasn't loaded, or when the
  /// category was deleted out from under the rule: the row then says the
  /// category is missing rather than leaving a blank.
  final AppCategory? category;

  /// The target's parent when the target is a subcategory.
  final AppCategory? parent;

  /// Transactions the rule classes; `null` while the counts load.
  final int? matchCount;

  /// The row's index in the reorderable list, for the grip.
  final int index;

  /// `false` while the list is filtered on a category: the grip is hidden,
  /// because moving a rule within a subset says nothing about where it lands
  /// among the rules the filter hides.
  final bool canReorder;

  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final dimmed = !rule.enabled;
    final secondary = dimmed ? colors.textTertiary : colors.textSecondary;
    final secondaryStyle = textTheme.bodyMedium?.copyWith(color: secondary);

    return AppTableRow(
      key: Key('ruleEdit-${rule.id}'),
      columns: columns,
      dimmed: dimmed,
      onTap: onEdit,
      cells: [
        const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReorder)
              ReorderableDragStartListener(
                index: index,
                // `click`, not `grab`: Flutter on Windows has no native grab
                // cursor and falls back to the arrow, which hides that the
                // row can be dragged at all. The empty tap keeps a press on
                // the grip from opening the editor.
                child: MouseRegion(
                  key: Key('ruleHandle-${rule.id}'),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {},
                    child: Icon(
                      LucideIcons300.gripVertical,
                      size: AppSizes.iconSmall,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              )
            else
              // The grip is hidden while filtered; its room stays, so the
              // positions line up with the column's header either way.
              const SizedBox(width: AppSizes.iconSmall),
            const SizedBox(width: AppSpacing.xsPlus),
            Text(
              '$position',
              key: Key('rulePosition-${rule.id}'),
              style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        Text(ruleFieldLabel(l10n, rule.matchField), style: secondaryStyle),
        Text(
          ruleConditionLabel(l10n, rule.matchType),
          key: Key('ruleCondition-${rule.id}'),
          style: secondaryStyle,
        ),
        Row(
          children: [
            if (rule.logo case final logo?) ...[
              InstitutionAvatar(
                key: Key('ruleLogo-${rule.id}'),
                name: rule.pattern,
                logo: logo,
                size: MonogramAvatar.small,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                rule.pattern,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.mono.copyWith(
                  color: dimmed ? colors.textTertiary : colors.text,
                ),
              ),
            ),
            if (rule.appliesFrom case final from?) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  l10n.ruleAppliesFrom(from),
                  key: Key('ruleAppliesFrom-${rule.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        RuleTargetLabel(category: category, parent: parent),
        Text(
          matchCount == null ? '' : '$matchCount',
          key: Key('ruleMatches-${rule.id}'),
          style: secondaryStyle,
        ),
        AppToggle(
          key: Key('ruleToggle-${rule.id}'),
          value: rule.enabled,
          semanticLabel: l10n.ruleToggleSemantics,
          onChanged: onToggle,
        ),
        const SizedBox.shrink(),
      ],
    );
  }
}

/// The category label of a rule's target (`00` §7): the top-level category's
/// hue and name, then the subcategory after « › ».
class RuleTargetLabel extends StatelessWidget {
  const RuleTargetLabel({
    super.key,
    required this.category,
    required this.parent,
  });

  final AppCategory? category;
  final AppCategory? parent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = category;
    if (target == null) {
      return CategoryLabel.uncategorized(label: l10n.ruleTargetMissing);
    }
    final root = parent ?? target;
    return CategoryLabel.slotted(
      label: localizedCategoryName(l10n, root.name),
      slot: categorySlot(root),
      subcategory: parent == null
          ? null
          : localizedCategoryName(l10n, target.name),
    );
  }
}

/// The category label's 8 px dot (`00` §7) in front of each category of a
/// target select, so the closed field reads as the label the mockup draws.
class RuleCategoryDot extends StatelessWidget {
  const RuleCategoryDot({super.key, required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CategoryLabel.dotSize,
      height: CategoryLabel.dotSize,
      decoration: BoxDecoration(
        color: context.categoryColors.forSlot(categorySlot(category)),
        borderRadius: BorderRadius.circular(AppRadii.bar),
      ),
    );
  }
}
