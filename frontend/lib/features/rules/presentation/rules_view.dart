import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/rule_match_counts.dart';
import '../application/rules_controller.dart';
import '../application/rules_filter.dart';
import '../domain/rule.dart';
import 'rule_editor_modal.dart';
import 'rule_error_localizer.dart';
import 'rule_pack_actions.dart';
import 'rule_row.dart';

/// The rules pane of the categories panel (`docs/design/08` §Rules pane):
/// « Règles », the category it is filtered on, the priority note and the
/// pack actions, over the ordered rules table.
///
/// It reads the category catalog from the categories controller rather than
/// fetching its own: the tree beside it shows the same catalog, and a second
/// copy would let a rule's target disagree with the tree.
class RulesView extends ConsumerWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rules = ref.watch(visibleRulesProvider);
    final filter = ref.watch(rulesCategoryFilterProvider);
    final filtered = filter != null;

    return Column(
      key: const Key('rulesPane'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: _RulesPaneHeader(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: switch (rules) {
            // Filtered to nothing is not "you have no rules": the cold-start
            // explanation would be wrong, so the pane says what the filter
            // found.
            AsyncData(:final value) when value.isEmpty && filtered => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.smPlus,
              ),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Row(
                  key: const Key('rulesFilterEmpty'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: NoteLine(text: l10n.rulesFilterEmpty)),
                    const SizedBox(width: AppSpacing.sm),
                    _RulesLink(
                      key: const Key('rulesFilterEmptyAdd'),
                      label: l10n.rulesAddButton,
                      onTap: () =>
                          showRuleEditor(context, initialCategoryId: filter),
                    ),
                  ],
                ),
              ),
            ),
            AsyncData(:final value) when value.isEmpty => const RulesEmptyState(
              extraAction: BuiltinPackOffer(),
            ),
            AsyncData(:final value) => _RulesTable(
              rules: value,
              canReorder: !filtered,
            ),
            AsyncError(:final error) => ErrorStateView(
              message: localizeRuleError(l10n, error),
              messageKey: const Key('rulesErrorText'),
              retryLabel: l10n.rulesRetry,
              retryKey: const Key('rulesRetryButton'),
              onRetry: () =>
                  ref.read(rulesControllerProvider.notifier).refresh(),
            ),
            _ => const _RulesSkeleton(),
          },
        ),
      ],
    );
  }
}

/// « Règles » 13/600 · the filter select-look · spacer · the priority note ·
/// the pack actions.
class _RulesPaneHeader extends ConsumerWidget {
  const _RulesPaneHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: AppSizes.toolbarSelect,
      child: Row(
        children: [
          Text(l10n.rulesPaneTitle, style: textTheme.titleSmall),
          const _CategoryFilterSelect(),
          const SizedBox(width: AppSpacing.md),
          // One line, ellipsized: the pane leaves the note little width in a
          // narrow window. The tooltip keeps the whole sentence reachable.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: l10n.rulesPriorityNote,
                child: Text(
                  l10n.rulesPriorityNote,
                  key: const Key('rulesPriorityNote'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const RulePackActions(),
        ],
      ),
    );
  }
}

/// The category the pane is filtered on, as a 28 px select-look holding its
/// category label and an `x` that returns to « Toutes les règles ». Nothing
/// at all when the pane shows every rule.
class _CategoryFilterSelect extends ConsumerWidget {
  const _CategoryFilterSelect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(rulesCategoryFilterProvider);
    if (filter == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final categories =
        ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    final category = categories
        .where((entry) => entry.id == filter)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.smPlus),
      child: Container(
        key: const Key('rulesFilterChip'),
        height: AppSizes.toolbarSelect,
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.sm + AppSpacing.xxs,
          end: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.field,
          border: Border.all(color: colors.lineStrong),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RuleTargetLabel(category: category, parent: null),
            const SizedBox(width: AppSpacing.xsPlus),
            Tooltip(
              message: l10n.rulesFilterClear,
              child: Semantics(
                button: true,
                label: l10n.rulesFilterClear,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const Key('rulesFilterClear'),
                    onTap: () => ref
                        .read(rulesCategoryFilterProvider.notifier)
                        .set(null),
                    child: Icon(
                      LucideIcons300.x,
                      size: AppSizes.iconSmall,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesTable extends ConsumerWidget {
  const _RulesTable({required this.rules, required this.canReorder});

  final List<Rule> rules;
  final bool canReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories =
        ref.watch(categoriesControllerProvider).value ?? const <AppCategory>[];
    final byId = {for (final category in categories) category.id: category};
    final positions = ref.watch(rulePositionsProvider);
    final counts = ref.watch(ruleMatchCountsProvider).value;
    final columns = ruleTableColumns(l10n);

    Widget row(BuildContext context, int index) {
      final rule = rules[index];
      final category = byId[rule.categoryId];
      return KeyedSubtree(
        key: Key('ruleRow-${rule.id}'),
        child: RuleRow(
          rule: rule,
          columns: columns,
          position: positions[rule.id] ?? index + 1,
          category: category,
          parent: category?.parentId == null ? null : byId[category!.parentId],
          matchCount: counts?[rule.id],
          index: index,
          canReorder: canReorder,
          onEdit: () => showRuleEditor(context, initial: rule),
          onToggle: (enabled) => _toggle(context, ref, l10n, rule, enabled),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTableHeader(columns: columns),
        Expanded(
          child: canReorder
              ? ReorderableListView.builder(
                  key: const Key('rulesList'),
                  buildDefaultDragHandles: false,
                  itemCount: rules.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorder(context, ref, oldIndex, newIndex),
                  itemBuilder: row,
                )
              : ListView.builder(
                  key: const Key('rulesList'),
                  itemCount: rules.length,
                  itemBuilder: row,
                ),
        ),
      ],
    );
  }
}

/// `onReorderItem` hands over the destination the row actually lands on, with
/// the removal at `oldIndex` already accounted for, which is what the
/// controller works in.
Future<void> _reorder(
  BuildContext context,
  WidgetRef ref,
  int oldIndex,
  int newIndex,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await ref
        .read(rulesControllerProvider.notifier)
        .reorder(oldIndex, newIndex);
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
    await ref
        .read(rulesControllerProvider.notifier)
        .setEnabled(rule.id, enabled);
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

/// The rows' silhouette while the rules load.
class _RulesSkeleton extends StatelessWidget {
  const _RulesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('rulesLoadingIndicator'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SkeletonPulse(
        child: Column(
          children: [
            for (var i = 0; i < 6; i++) ...[
              const SizedBox(height: AppSpacing.sm),
              const SkeletonBlock(height: AppSizes.tableRow - AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// A link (`00` §6): `accent`, 12 px, underlined on hover, focusable.
class _RulesLink extends StatefulWidget {
  const _RulesLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_RulesLink> createState() => _RulesLinkState();
}

class _RulesLinkState extends State<_RulesLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.item,
          child: Semantics(
            link: true,
            child: Text(
              widget.label,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.accent,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: colors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rules empty state: what a rule is, then the way to make one, and the
/// bundled pack below it.
class RulesEmptyState extends StatelessWidget {
  const RulesEmptyState({super.key, this.extraAction});

  /// Slot for the bundled-pack offer.
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return EmptyStateView(
      key: const Key('rulesEmptyState'),
      title: l10n.rulesEmptyTitle,
      message: l10n.rulesEmptyBody,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            key: const Key('emptyStateAddRuleButton'),
            label: l10n.rulesAddButton,
            icon: LucideIcons300.plus,
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
