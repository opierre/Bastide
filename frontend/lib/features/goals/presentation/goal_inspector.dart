import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inspector_pane.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';
import 'allocation_modal.dart';
import 'delete_allocation_modal.dart';
import 'goal_banner.dart';
import 'goal_form_modal.dart';
import 'goal_labels.dart';

/// The repère tone of a goal: `muted` archived, `done` reached.
RepereTone goalRepereTone(Goal goal) => goal.isArchived
    ? RepereTone.muted
    : goal.isReached
    ? RepereTone.done
    : RepereTone.normal;

/// The inspector pane of the Objectifs panel (`11-goals.md` §Inspector pane):
/// the banner edge to edge, then the figures with « Archiver », the repère,
/// and the allocations with « Allouer ».
///
/// An archived goal shows « Désarchiver » in place of « Archiver », no
/// « Allouer », and no delete action on its allocation rows.
class GoalInspector extends ConsumerWidget {
  const GoalInspector({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InspectorPane(
      key: const Key('goalInspector'),
      selection: goal.id,
      header: GoalBanner(goal: goal),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppGoalBanner.contentTop,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      blocks: [
        _Figures(goal: goal),
        _Allocations(goal: goal),
      ],
    );
  }
}

class _Figures extends ConsumerWidget {
  const _Figures({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final controller = ref.read(goalsControllerProvider.notifier);
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: goal.currency,
      locale: locale,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        money(goal.progressMinor),
                        key: Key('goalInspectorSaved-${goal.id}'),
                        style: tabularNumberStyle(textTheme.displayMedium!),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.goalOfTarget(money(goal.targetMinor)),
                      key: Key('goalInspectorTarget-${goal.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tabularNumberStyle(
                        textTheme.bodyMedium!,
                      ).copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!goal.isArchived) ...[
              AppButton(
                key: const Key('goalEdit'),
                label: l10n.goalEdit,
                icon: LucideIcons300.pencil,
                iconOnly: true,
                onPressed: () => showGoalForm(context, initial: goal),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            goal.isArchived
                ? AppButton(
                    key: const Key('goalUnarchive'),
                    label: l10n.goalUnarchive,
                    icon: LucideIcons300.archiveRestore,
                    onPressed: () => controller.restore(goal.id),
                  )
                : AppButton(
                    key: const Key('goalArchive'),
                    label: l10n.goalArchive,
                    icon: LucideIcons300.archive,
                    onPressed: () => controller.archive(goal.id),
                  ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        RepereMeter(
          key: Key('goalInspectorMeter-${goal.id}'),
          fraction: goal.barFraction,
          tone: goalRepereTone(goal),
          semanticLabel: goalPercentLabel(goal.progressPct, locale),
        ),
        if (!goal.isReached) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.goalDeadlineRemaining(
              goalDeadlineLabel(l10n, locale, goal),
              money(goal.remainingMinor),
            ),
            key: Key('goalInspectorRemaining-${goal.id}'),
            style: tabularNumberStyle(
              textTheme.bodySmall!,
            ).copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _Allocations extends ConsumerWidget {
  const _Allocations({required this.goal});

  final Goal goal;

  static const _columns = [
    AppTableColumn(label: '', width: 88),
    AppTableColumn(label: ''),
    AppTableColumn(label: '', width: 112, numeric: true),
  ];

  /// The same table with a trailing column for the row's delete action.
  static const _columnsWithAction = [
    ..._columns,
    AppTableColumn(label: '', width: AppSizes.button + AppSpacing.smPlus),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final allocations = ref.watch(goalAllocationsProvider(goal.id));
    final hint = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textTertiary);

    return Column(
      key: Key('goalAllocations-${goal.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.goalAllocationsTitle,
          trailing: goal.isArchived
              ? null
              : AppButton(
                  key: const Key('goalAllocate'),
                  label: l10n.goalAllocate,
                  icon: LucideIcons300.plus,
                  onPressed: () => showAllocationModal(context, goal: goal),
                ),
        ),
        switch (allocations) {
          AsyncData(:final value) when value.isEmpty => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.goalAllocationsEmpty,
              key: const Key('goalAllocationsEmpty'),
              style: hint,
            ),
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final allocation in value)
                _AllocationRow(
                  allocation: allocation,
                  currency: goal.currency,
                  columns: goal.isArchived ? _columns : _columnsWithAction,
                  onDelete: goal.isArchived
                      ? null
                      : () => showDeleteAllocationModal(
                          context,
                          goal: goal,
                          allocation: allocation,
                        ),
                ),
            ],
          ),
          AsyncError() => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.goalAllocationsFailed,
              key: const Key('goalAllocationsFailed'),
              style: hint,
            ),
          ),
          _ => const SizedBox(height: AppSizes.tableRow),
        },
      ],
    );
  }
}

/// One ledger line. The delete action shows on hover or keyboard focus only,
/// so the history reads as a plain list until the user reaches for a row.
class _AllocationRow extends StatefulWidget {
  const _AllocationRow({
    required this.allocation,
    required this.currency,
    required this.columns,
    this.onDelete,
  });

  final GoalAllocation allocation;
  final String currency;
  final List<AppTableColumn> columns;

  /// `null` for an archived goal: its history is read-only.
  final VoidCallback? onDelete;

  @override
  State<_AllocationRow> createState() => _AllocationRowState();
}

class _AllocationRowState extends State<_AllocationRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final allocation = widget.allocation;
    final onDelete = widget.onDelete;

    final row = AppTableRow(
      key: Key('goalAllocationRow-${allocation.id}'),
      columns: widget.columns,
      cells: [
        Text(
          appDateFormat(locale).format(allocation.allocatedOn),
          maxLines: 1,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: colors.textSecondary),
        ),
        Text(
          allocation.note ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AmountText(
          amountMinor: allocation.amountMinor,
          currency: widget.currency,
          showPositiveSign: true,
          maxLines: 1,
          style: tabularNumberStyle(textTheme.bodyMedium!),
        ),
        if (onDelete != null)
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (focused) => setState(() => _focused = focused),
            // Kept in the tree while hidden so Tab still reaches it.
            child: Opacity(
              opacity: _hovered || _focused ? 1 : 0,
              child: AppButton(
                key: Key('goalAllocationDelete-${allocation.id}'),
                label: l10n.goalAllocationDelete,
                icon: LucideIcons300.trash2,
                iconOnly: true,
                variant: AppButtonVariant.ghost,
                onPressed: onDelete,
              ),
            ),
          ),
      ],
    );
    if (onDelete == null) return row;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: row,
    );
  }
}
