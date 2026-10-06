import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import 'goal_card.dart';
import 'goal_detail.dart';
import 'goal_form_modal.dart';
import 'goal_labels.dart';

/// The Objectifs panel: the goal grid with its progress, the allocation flow
/// behind each card, and the over-allocation warning (`docs/design/11-goals.md`).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static const path = '/goals';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGoalProvider);

    return Padding(
      key: const Key('screen-goals'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.contentX,
        vertical: AppSpacing.contentY,
      ),
      child: selected == null
          ? const _GoalsGrid()
          : GoalDetailView(goalId: selected),
    );
  }
}

/// The panel's contribution to the top bar: the primary « Nouvel objectif ».
///
/// It stays available on the detail view. The detail is a state of this panel,
/// not a different one, and chrome that rearranged itself under the user would
/// break the invariant the shell exists to hold (`docs/design/00` §Layout).
class GoalsTopBarActions extends ConsumerWidget {
  const GoalsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return PrimaryButton(
      key: const Key('addGoalButton'),
      label: l10n.goalsAdd,
      icon: Icons.add_rounded,
      onPressed: () => showGoalForm(context),
    );
  }
}

class _GoalsGrid extends ConsumerWidget {
  const _GoalsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(goalsControllerProvider);

    return switch (state) {
      AsyncData(:final value)
          when value.goals.isEmpty && value.archived.isEmpty =>
        EmptyStateView(
          key: const Key('goalsEmptyState'),
          icon: Icons.flag_rounded,
          title: l10n.goalsEmptyTitle,
          message: l10n.goalsEmptyBody,
          action: PrimaryButton(
            key: const Key('goalsEmptyAddButton'),
            label: l10n.goalsAdd,
            height: 44,
            onPressed: () => showGoalForm(context),
          ),
        ),
      AsyncData(:final value) => _LoadedPanel(state: value),
      AsyncError() => ErrorStateView(
        message: l10n.goalsLoadFailed,
        messageKey: const Key('goalsErrorText'),
        retryLabel: l10n.goalsRetry,
        retryKey: const Key('goalsRetryButton'),
        onRetry: () => ref.read(goalsControllerProvider.notifier).refresh(),
      ),
      _ => const Padding(
        key: Key('goalsLoadingIndicator'),
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: SkeletonList(itemHeight: 130, itemCount: 2),
      ),
    };
  }
}

/// Frame ①, top to bottom: the reassurance line, the over-allocation banner
/// when it applies, the card grid, and the archived-goals link.
class _LoadedPanel extends ConsumerWidget {
  const _LoadedPanel({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(goalsControllerProvider.notifier);
    final open = ref.read(selectedGoalProvider.notifier).open;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GoalReassuranceLine(),
        const SizedBox(height: AppSpacing.md),
        if (state.actionError != null) ...[
          InlineBanner(
            key: const Key('goalsActionError'),
            message: localizeGoalError(l10n, state.actionError),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.isOverAllocated && !state.bannerDismissed) ...[
          _OverAllocationBanner(
            state: state,
            onDismiss: controller.dismissOverAllocationBanner,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: ListView(
            key: const Key('goalsList'),
            children: [
              _CardGrid(goals: state.goals, onOpen: open),
              if (state.archived.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.gridGap),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('goalsArchivedToggle'),
                    onPressed: controller.toggleArchived,
                    icon: const Icon(Icons.archive_outlined, size: 15),
                    label: Text(
                      state.showArchived
                          ? l10n.goalsHideArchived(state.archived.length)
                          : l10n.goalsShowArchived(state.archived.length),
                    ),
                  ),
                ),
                if (state.showArchived) ...[
                  const SizedBox(height: AppSpacing.sm),
                  // Revealed *in place* rather than on a screen of their own: an
                  // archived goal is still one of the user's goals, and moving
                  // it elsewhere would make restoring it feel like a recovery
                  // rather than a change of mind.
                  _CardGrid(goals: state.archived, onOpen: open, dimmed: true),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The 2-column grid, gap 18.
///
/// Built as rows of two rather than a [GridView] because a goal card's height
/// is its content's: a grid would need a fixed aspect ratio, and the one that
/// fits « Fonds d'urgence » clips a longer name at another window width.
class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.goals,
    required this.onOpen,
    this.dimmed = false,
  });

  final List<Goal> goals;
  final ValueChanged<String> onOpen;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < goals.length; index += 2) {
      final left = goals[index];
      final right = index + 1 < goals.length ? goals[index + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.gridGap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GoalCard(
                  goal: left,
                  dimmed: dimmed,
                  onOpen: () => onOpen(left.id),
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(
                child: right == null
                    // An odd count leaves the slot empty rather than letting the
                    // last card stretch to the full width: a card twice its
                    // neighbours' size reads as a different kind of thing.
                    ? const SizedBox()
                    : GoalCard(
                        goal: right,
                        dimmed: dimmed,
                        onOpen: () => onOpen(right.id),
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// « Vous avez réparti 24 450,00 € alors que vos comptes d'épargne totalisent
/// 22 100,00 €. »
///
/// Informative and dismissible, never blocking. The app cannot be right
/// about which of a user's money is "savings", so it states the arithmetic and
/// leaves the judgment where it belongs.
class _OverAllocationBanner extends StatelessWidget {
  const _OverAllocationBanner({required this.state, required this.onDismiss});

  final GoalsState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    String money(int amountMinor) => formatAmount(
      amountMinor: amountMinor,
      currency: state.currency,
      locale: locale,
    );

    return InlineBanner(
      key: const Key('goalsOverAllocationBanner'),
      tone: BannerTone.info,
      message: l10n.goalsOverAllocated(
        money(state.allocatedTotalMinor),
        money(state.savingsTotalMinor),
      ),
      onDismiss: onDismiss,
      dismissTooltip: l10n.goalsDismissBanner,
    );
  }
}
