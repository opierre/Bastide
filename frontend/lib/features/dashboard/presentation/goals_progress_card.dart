import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_card.dart';

/// The dashboard's Objectifs card (`docs/design/04` §Row 3): the top
/// three active goals as compact rows, under an iris tint.
///
/// A read-only window onto the Objectifs panel — nothing here allocates or
/// archives. « Voir tout » is the one way out, exactly as the recent-activity
/// card links to the transactions feed: the dashboard reports, the panel acts.
///
/// The caller hides this card entirely when there are no goals; it never draws
/// its own empty state. An "you have no goals" plate on the dashboard would
/// spend a third of a row telling the user about a feature they haven't asked
/// for, on the screen that is meant to lead with their money.
class GoalsProgressCard extends StatelessWidget {
  const GoalsProgressCard({
    super.key,
    required this.goals,
    required this.onViewAll,
  });

  /// Already narrowed to the three the card draws — see
  /// `GoalsState.topGoals`, which owns that choice.
  final List<Goal> goals;

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      key: const Key('dashboardGoalsCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      gradient: AppColors.irisTintGradientSoft,
      border: Border.all(color: AppColors.irisBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashboardGoalsTitle,
                  style: textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('dashboardGoalsViewAll'),
                onPressed: onViewAll,
                child: Text(
                  l10n.dashboardGoalsViewAll,
                  style: textTheme.labelSmall?.copyWith(color: AppColors.iris),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          for (final goal in goals) ...[
            _GoalRow(goal: goal),
            if (goal != goals.last) const SizedBox(height: AppSpacing.md - 2),
          ],
        ],
      ),
    );
  }
}

/// One compact row: the name, the figures — or the reached badge in their place
/// — and a 6 px bar.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: Key('dashboardGoalRow-${goal.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (goal.isReached)
              // The amounts step aside for the badge: on a reached goal the
              // figures say the same thing twice, and the row has no width to
              // spend saying it.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.positive,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.dashboardGoalsReached,
                    key: Key('dashboardGoalReached-${goal.id}'),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.positive,
                    ),
                  ),
                ],
              )
            else
              Text(
                l10n.dashboardGoalsProgress(
                  formatAmount(
                    amountMinor: goal.progressMinor,
                    currency: goal.currency,
                    locale: locale,
                  ),
                  formatAmount(
                    amountMinor: goal.targetMinor,
                    currency: goal.currency,
                    locale: locale,
                  ),
                ),
                key: Key('dashboardGoalAmounts-${goal.id}'),
                style: tabularNumberStyle(textTheme.labelSmall!).copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        GoalProgressBar(fraction: goal.barFraction, height: 6),
      ],
    );
  }
}
