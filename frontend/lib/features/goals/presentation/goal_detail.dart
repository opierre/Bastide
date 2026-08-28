import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_allocation.dart';
import 'allocation_modal.dart';
import 'goal_labels.dart';

/// One goal in full (`docs/design/11-goals.md` frame ②): the progress ring and
/// the figures, the archive and allocate actions, and the allocation history.
///
/// A panel state rather than a route — same chrome, same top-bar controls, an
/// iris back link rather than a browser step.
///
/// The history is the point of the screen. A goal's progress is a claim about
/// money the app cannot see moving, so the lines that produced it are shown
/// beneath it, signed, with the note the user wrote at the time.
class GoalDetailView extends ConsumerWidget {
  const GoalDetailView({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(goalsControllerProvider).value;
    final goal = [
      ...?state?.goals,
      ...?state?.archived,
    ].where((candidate) => candidate.id == goalId).firstOrNull;

    return Column(
      key: const Key('goalDetail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('goalDetailBack'),
            onPressed: () => ref.read(selectedGoalProvider.notifier).close(),
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.iris),
            label: Text(
              l10n.goalDetailBack,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.iris),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: goal == null
              // The goal is gone from under the view — archived in another
              // window, or deleted. The grid is the only honest place to be.
              ? ErrorStateView(
                  message: l10n.goalDetailMissing,
                  messageKey: const Key('goalDetailMissing'),
                  retryLabel: l10n.goalDetailBack,
                  retryKey: const Key('goalDetailMissingBack'),
                  onRetry: () => ref.read(selectedGoalProvider.notifier).close(),
                )
              : _DetailBody(goal: goal),
        ),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final allocations = ref.watch(goalAllocationsProvider(goal.id));

    return ListView(
      key: const Key('goalDetailContent'),
      children: [
        _HeaderCard(goal: goal),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        const GoalReassuranceLine(),
        const SizedBox(height: AppSpacing.gridGap),
        switch (allocations) {
          AsyncData(:final value) => _HistoryCard(goal: goal, allocations: value),
          AsyncError() => ErrorStateView(
            message: l10n.goalDetailHistoryFailed,
            messageKey: const Key('goalHistoryErrorText'),
            retryLabel: l10n.goalsRetry,
            retryKey: const Key('goalHistoryRetryButton'),
            onRetry: () => ref.invalidate(goalAllocationsProvider(goal.id)),
          ),
          // Sized, because this sits inside the detail's own scroll view and
          // a [SkeletonList]'s ListView has no height of its own there. Three
          // 44 px rows and the two gaps between them — the silhouette of the
          // history that is about to land.
          _ => const SizedBox(
            height: 156,
            child: SkeletonList(
              key: Key('goalHistoryLoading'),
              itemCount: 3,
              itemHeight: 44,
            ),
          ),
        },
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Text(
          l10n.goalDetailFootnote,
          key: const Key('goalDetailFootnote'),
          style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
        ),
      ],
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(goalsControllerProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GoalProgressRing(goal: goal),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  goal.name,
                  key: const Key('goalDetailName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                // The date, or its absence — and nothing else. No account line
                // here either: the detail header is one of the three places
                // `11-goals.md` names explicitly (§Concept).
                Text(
                  goal.targetDate == null
                      ? l10n.goalPillNoDeadline
                      : l10n.goalDetailTargetDate(
                          goalMonthLabel(locale, goal.targetDate!),
                        ),
                  key: const Key('goalDetailSubline'),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      key: const Key('goalDetailSaved'),
                      amountMinor: goal.progressMinor,
                      currency: goal.currency,
                      colorize: false,
                      style: textTheme.displayMedium!.copyWith(fontSize: 24),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '/ ${formatAmount(amountMinor: goal.targetMinor, currency: goal.currency, locale: locale)}',
                        key: const Key('goalDetailTarget'),
                        style: tabularNumberStyle(
                          textTheme.bodyMedium!,
                        ).copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            height: AppChrome.controlPillHeight,
            child: OutlinedButton.icon(
              key: const Key('goalArchiveButton'),
              onPressed: () => goal.isArchived
                  ? controller.restore(goal.id)
                  : controller.archive(goal.id),
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: Text(
                goal.isArchived ? l10n.goalDetailRestore : l10n.goalDetailArchive,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          PrimaryButton(
            key: const Key('goalAllocateButton'),
            label: l10n.goalDetailNewAllocation,
            icon: Icons.add_rounded,
            onPressed: () => showAllocationModal(context, goal: goal),
          ),
        ],
      ),
    );
  }
}

/// The 96 px progress ring: r 40, stroke 10, drawn from 12 o'clock clockwise,
/// with the percentage set in its middle.
///
/// Same recipe as the dashboard's savings-rate ring — the indicator is sized to
/// 90 inside the 96 slot because Flutter measures the arc's radius from the box
/// edge inwards by half the stroke, so `(90 − 10) / 2` is the spec's r 40. The
/// arc clamps at full while the label reports the real figure, exactly as the
/// grid card's bar and percentage do.
class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({super.key, required this.goal});

  final Goal goal;

  static const _size = 96.0;
  static const _stroke = 10.0;
  static const _radius = 40.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final accent = goal.isReached ? AppColors.positive : AppColors.iris;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: _radius * 2 + _stroke,
            height: _radius * 2 + _stroke,
            child: CircularProgressIndicator(
              value: goal.barFraction,
              strokeWidth: _stroke,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.surfaceHover,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          Text(
            goalPercentLabel(goal.progressPct, locale),
            key: Key('goalRingPercent-${goal.id}'),
            style: tabularNumberStyle(
              Theme.of(context).textTheme.displayMedium!,
            ).copyWith(fontSize: 20, color: accent),
          ),
        ],
      ),
    );
  }
}

/// « Répartition sur le papier : vos comptes ne sont pas modifiés. »
///
/// On the grid *and* on the detail, because both are places a user could
/// reasonably start to believe that allocating moved real money — and the whole
/// feature rests on them not believing that (`PROJECT.md` §13).
class GoalReassuranceLine extends StatelessWidget {
  const GoalReassuranceLine({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      key: const Key('goalReassuranceLine'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textDisabled),
        const SizedBox(width: AppSpacing.sm - 2),
        Flexible(
          child: Text(
            l10n.goalsReassurance,
            style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
          ),
        ),
      ],
    );
  }
}

/// The allocation ledger: one list, signed amounts, newest first.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.goal, required this.allocations});

  final Goal goal;
  final List<GoalAllocation> allocations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.goalHistoryTitle, style: textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            l10n.goalHistorySubtitle,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (allocations.isEmpty)
            Text(
              l10n.goalHistoryEmpty,
              key: const Key('goalHistoryEmpty'),
              style: AppTextStyles.helper,
            )
          else ...[
            const _HistoryHeader(),
            for (final allocation in allocations)
              _HistoryRow(
                allocation: allocation,
                currency: goal.currency,
                onDelete: () => ref
                    .read(goalsControllerProvider.notifier)
                    .deleteAllocation(goal.id, allocation.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              l10n.goalHistoryDate.toUpperCase(),
              style: AppTextStyles.sectionLabel,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              l10n.goalHistoryAmount.toUpperCase(),
              textAlign: TextAlign.end,
              style: AppTextStyles.sectionLabel,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.goalHistoryNote.toUpperCase(),
              style: AppTextStyles.sectionLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.allocation,
    required this.currency,
    required this.onDelete,
  });

  final GoalAllocation allocation;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      key: Key('goalAllocation-${allocation.id}'),
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              goalDateFormat(locale).format(allocation.allocatedOn),
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerRight,
              // Signed and colorized — green in, red out. These lines are
              // movements, even though the money they describe never leaves an
              // account, so they follow the ledger's own rule.
              child: AmountText(
                key: Key('goalAllocationAmount-${allocation.id}'),
                amountMinor: allocation.amountMinor,
                currency: currency,
                showPositiveSign: true,
                style: textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              allocation.note ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          IconButton(
            key: Key('goalAllocationDelete-${allocation.id}'),
            onPressed: onDelete,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.goalHistoryDelete,
            icon: const Icon(Icons.close_rounded, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
