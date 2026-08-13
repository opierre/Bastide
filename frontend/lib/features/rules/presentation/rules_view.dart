import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/rules_controller.dart';
import '../domain/rule.dart';
import 'rule_editor_modal.dart';
import 'rule_error_localizer.dart';
import 'rule_pack_menu.dart';
import 'rule_row.dart';

/// The rules half of the categories panel: the priority note and the « Exécuter
/// les règles » action, over a drag-reorderable card of 52 px rows.
///
/// It reads the category catalog from the categories controller rather than
/// fetching its own: the two views are one panel, and the catalog is precisely
/// what they share — a second copy would let a rule's target chip disagree with
/// the tree standing beside it.
class RulesView extends ConsumerWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rules = ref.watch(rulesControllerProvider);

    return switch (rules) {
      AsyncData(:final value) when value.isEmpty => const RulesEmptyState(
        extraAction: BuiltinPackOffer(),
      ),
      AsyncData(:final value) => _RulesCard(rules: value),
      AsyncError(:final error) => ErrorStateView(
        message: localizeRuleError(l10n, error),
        messageKey: const Key('rulesErrorText'),
        retryLabel: l10n.rulesRetry,
        retryKey: const Key('rulesRetryButton'),
        onRetry: () => ref.read(rulesControllerProvider.notifier).refresh(),
      ),
      _ => const Padding(
        key: Key('rulesLoadingIndicator'),
        padding: EdgeInsets.only(top: 24),
        child: SkeletonList(itemHeight: 52),
      ),
    };
  }
}

class _RulesCard extends ConsumerWidget {
  const _RulesCard({required this.rules});

  final List<Rule> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    final byId = {for (final category in categories) category.id: category};

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: ReorderableListView.builder(
        key: const Key('rulesList'),
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        itemCount: rules.length,
        onReorderItem: (oldIndex, newIndex) => _reorder(context, ref, oldIndex, newIndex),
        itemBuilder: (context, index) {
          final rule = rules[index];
          return Padding(
            key: Key('ruleRow-${rule.id}'),
            padding: EdgeInsets.zero,
            child: RuleRow(
              rule: rule,
              category: byId[rule.categoryId],
              index: index,
              onEdit: () => showRuleEditor(context, initial: rule),
              onToggle: (enabled) => _toggle(context, ref, l10n, rule, enabled),
            ),
          );
        },
      ),
    );
  }
}

/// `onReorderItem` hands over the destination the row actually lands on, with
/// the removal at `oldIndex` already accounted for — which is what the
/// controller works in. (Its predecessor, `onReorder`, reported a slot in the
/// list *before* the lift and needed a manual `-1` on downward moves.)
Future<void> _reorder(
  BuildContext context,
  WidgetRef ref,
  int oldIndex,
  int newIndex,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await ref.read(rulesControllerProvider.notifier).reorder(oldIndex, newIndex);
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(
      context,
      title: l10n.rulesReorderFailed,
      message: localizeRuleError(l10n, error),
      tone: BannerTone.error,
    );
  }
}

Future<void> _toggle(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  Rule rule,
  bool enabled,
) async {
  try {
    await ref.read(rulesControllerProvider.notifier).setEnabled(rule.id, enabled);
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(
      context,
      title: l10n.rulesToggleFailed,
      message: localizeRuleError(l10n, error),
      tone: BannerTone.error,
    );
  }
}

/// The note and the run action that head the rules view, right of the panel's
/// segmented control (`docs/design/08`).
class RulesViewHeaderActions extends ConsumerStatefulWidget {
  const RulesViewHeaderActions({super.key});

  @override
  ConsumerState<RulesViewHeaderActions> createState() => _RulesViewHeaderActionsState();
}

class _RulesViewHeaderActionsState extends ConsumerState<RulesViewHeaderActions> {
  bool _isApplying = false;

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isApplying = true);
    try {
      final count = await ref.read(rulesControllerProvider.notifier).apply();
      if (!mounted) return;
      // Two lines, because the count alone leaves the question the second one
      // answers: the run never overwrites a category the user chose by hand
      // (PROJECT.md §7), and a bulk action that doesn't say so invites an undo
      // the app can't offer.
      showAppToast(
        context,
        title: l10n.rulesApplyToastTitle(count),
        message: l10n.rulesApplyToastBody,
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        title: l10n.rulesApplyFailed,
        message: localizeRuleError(l10n, error),
        tone: BannerTone.error,
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.rulesPriorityNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton(
          key: const Key('applyRulesButton'),
          onPressed: _isApplying ? null : _apply,
          child: Text(_isApplying ? l10n.rulesApplyRunning : l10n.rulesApplyButton),
        ),
        const SizedBox(width: AppSpacing.xs),
        const RulePackMenu(),
      ],
    );
  }
}

/// The rules empty state: what a rule *is*, then the way to make one.
class RulesEmptyState extends StatelessWidget {
  const RulesEmptyState({super.key, this.extraAction});

  /// Slot for the bundled-pack offer, which the pack slice fills in.
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return EmptyStateView(
      key: const Key('rulesEmptyState'),
      icon: Icons.rule_rounded,
      title: l10n.rulesEmptyTitle,
      message: l10n.rulesEmptyBody,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            key: const Key('emptyStateAddRuleButton'),
            label: l10n.rulesAddButton,
            icon: Icons.add_rounded,
            height: 44,
            onPressed: () => showRuleEditor(context),
          ),
          if (extraAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            extraAction!,
          ],
        ],
      ),
    );
  }
}
