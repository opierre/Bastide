import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import 'goal_form_modal.dart';
import 'goal_inspector.dart';
import 'goals_list_pane.dart';

/// The Objectifs panel (`docs/design/11-goals.md`): a flush panel of two
/// panes, the goals list and the inspector of the selected goal.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static const path = '/goals';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(goalsControllerProvider);
    final selectedId = ref.watch(selectedGoalProvider);

    final padded = EdgeInsets.symmetric(
      horizontal: AppSpacing.pageX,
      vertical: AppSpacing.pageY,
    );

    return KeyedSubtree(
      key: const Key('screen-goals'),
      child: switch (state) {
        AsyncData(:final value)
            when value.goals.isEmpty && value.archived.isEmpty =>
          Padding(
            padding: padded,
            child: EmptyStateView(
              key: const Key('goalsEmptyState'),
              title: l10n.goalsEmptyTitle,
              message: l10n.goalsEmptyBody,
              action: PrimaryButton(
                key: const Key('goalsEmptyAddButton'),
                label: l10n.goalsAdd,
                icon: LucideIcons300.plus,
                onPressed: () => showGoalForm(context),
              ),
            ),
          ),
        AsyncData(:final value) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GoalsListPane(
                state: value,
                selected: value.selectedIn(selectedId),
              ),
            ),
            if (value.selectedIn(selectedId) case final goal?)
              GoalInspector(goal: goal)
            else
              const _EmptyInspector(),
          ],
        ),
        AsyncError() => Padding(
          padding: padded,
          child: ErrorStateView(
            message: l10n.goalsLoadFailed,
            messageKey: const Key('goalsErrorText'),
            retryLabel: l10n.goalsRetry,
            retryKey: const Key('goalsRetryButton'),
            onRetry: () => ref.read(goalsControllerProvider.notifier).refresh(),
          ),
        ),
        _ => const _GoalsSkeleton(),
      },
    );
  }
}

/// The panel's contribution to the title bar: the primary « Nouvel objectif »
/// (`plus`).
class GoalsTopBarActions extends ConsumerWidget {
  const GoalsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return PrimaryButton(
      key: const Key('addGoalButton'),
      label: l10n.goalsAdd,
      icon: LucideIcons300.plus,
      onPressed: () => showGoalForm(context),
    );
  }
}

/// The inspector's ground when only archived goals exist and their list is
/// folded: nothing is selected.
class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: AppSizes.inspector,
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(left: BorderSide(color: colors.line)),
      ),
    );
  }
}

/// Loading: the silhouettes of both panes (`00` §7 States of a panel).
class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SkeletonPulse(
      key: const Key('goalsLoadingIndicator'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageX,
                vertical: AppSpacing.pageY,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBlock(height: 12, width: 160),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonBlock(height: 40, width: 240),
                  const SizedBox(height: AppSpacing.lg),
                  for (var i = 0; i < 4; i++) ...[
                    const SkeletonBlock(height: AppSizes.tableRowTwoLines - 8),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          Container(
            width: AppSizes.inspector,
            decoration: BoxDecoration(
              color: colors.rail,
              border: Border(left: BorderSide(color: colors.line)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBlock(height: AppGoalBanner.heightEmpty, radius: 0),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(height: 28, width: 200),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBlock(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
