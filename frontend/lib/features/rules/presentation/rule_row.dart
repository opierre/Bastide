import 'package:flutter/material.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../domain/rule.dart';
import 'rule_labels.dart';

/// A 52 px rule row: handle · priority plate · field · condition badge ·
/// monospace pattern · → target chip · enable toggle (`docs/design/08`).
///
/// A disabled rule renders at half opacity *and* with its toggle off — the
/// wash alone would be indistinguishable from a row that simply lost focus.
/// Opacity doesn't affect hit testing, so the toggle stays reachable, which is
/// the whole point of showing a disabled rule rather than hiding it.
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.rule,
    required this.category,
    required this.index,
    required this.onEdit,
    required this.onToggle,
  });

  final Rule rule;

  /// The rule's target. `null` when the catalog hasn't loaded yet, or when the
  /// category was deleted out from under the rule — rendered as the dashed
  /// uncategorized chip rather than as a blank, so the gap is visible.
  final AppCategory? category;

  /// Position in the reorderable list, used for the drag handle.
  final int index;

  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: Opacity(
        opacity: rule.enabled ? 1 : 0.5,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _PriorityPlate(priority: rule.priority),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: Key('ruleEdit-${rule.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          ruleFieldLabel(l10n, rule.matchField),
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      AppChip(
                        key: Key('ruleCondition-${rule.id}'),
                        label: ruleConditionLabel(l10n, rule.matchType),
                      ),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Expanded(
                        child: Text(
                          rule.pattern,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.mono.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TargetChip(category: category),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppToggle(
              key: Key('ruleToggle-${rule.id}'),
              value: rule.enabled,
              semanticLabel: l10n.ruleToggleSemantics,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// The evaluation order, stated as a number on an inset plate. Rules are
/// applied ascending and the first match wins, so this is the row's most
/// load-bearing figure after the pattern itself.
class _PriorityPlate extends StatelessWidget {
  const _PriorityPlate({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$priority',
        style: tabularNumberStyle(
          Theme.of(context).textTheme.labelSmall!,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.category});

  final AppCategory? category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final target = category;
    if (target == null) {
      return CategoryChip.uncategorized(label: l10n.ruleTargetMissing);
    }
    return CategoryChip(
      label: localizedCategoryName(l10n, target.name),
      slug: categorySlugFor(name: target.name, kind: target.kind),
    );
  }
}
