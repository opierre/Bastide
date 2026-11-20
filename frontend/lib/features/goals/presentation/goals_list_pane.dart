import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import 'goal_inspector.dart';
import 'goal_labels.dart';

/// The list pane of the Objectifs panel (`11-goals.md` §List pane), top to
/// bottom 16 px apart: the summary line, the over-allocation banner, the
/// goals table, the archived-goals link (and the archived rows under it),
/// and the note.
class GoalsListPane extends ConsumerWidget {
  const GoalsListPane({super.key, required this.state, required this.selected});

  final GoalsState state;

  /// The goal the inspector shows.
  final Goal? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(goalsControllerProvider.notifier);
    final select = ref.read(selectedGoalProvider.notifier).select;

    return Padding(
      key: const Key('goalsListPane'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryLine(state: state),
          if (state.actionError != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('goalsActionError'),
              message: localizeGoalError(l10n, state.actionError),
              onDismiss: controller.clearActionError,
              dismissTooltip: l10n.goalsDismissBanner,
            ),
          ],
          if (state.isOverAllocated && !state.bannerDismissed) ...[
            const SizedBox(height: AppSpacing.md),
            _OverAllocationBanner(
              state: state,
              onDismiss: controller.dismissOverAllocationBanner,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = _columns(l10n, constraints.maxWidth);
                return ListView(
                  key: const Key('goalsList'),
                  children: [
                    AppTableHeader(columns: columns),
                    for (final goal in state.goals)
                      _GoalRow(
                        goal: goal,
                        columns: columns,
                        selected: goal.id == selected?.id,
                        onTap: () => select(goal.id),
                      ),
                    if (state.archived.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ArchivedLink(
                        count: state.archived.length,
                        open: state.showArchived,
                        onTap: controller.toggleArchived,
                      ),
                      if (state.showArchived) ...[
                        const SizedBox(height: AppSpacing.sm),
                        for (final goal in state.archived)
                          _GoalRow(
                            goal: goal,
                            columns: columns,
                            selected: goal.id == selected?.id,
                            onTap: () => select(goal.id),
                          ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NoteLine(
            key: const Key('goalsNote'),
            icon: LucideIcons300.lock,
            text: l10n.goalsNote,
          ),
        ],
      ),
    );
  }

  /// The table's columns at [width]: « Avancement » takes 30 % of it, the
  /// figures a fixed width, the name and the deadline share the rest.
  static List<AppTableColumn> _columns(AppLocalizations l10n, double width) => [
    AppTableColumn(label: l10n.goalsColumnGoal, flex: 3),
    AppTableColumn(label: l10n.goalsColumnDeadline, flex: 2),
    AppTableColumn(label: l10n.goalsColumnProgress, width: width * 0.3),
    AppTableColumn(label: l10n.goalsColumnReserved, width: 184, numeric: true),
    const AppTableColumn(label: '', width: 52, numeric: true),
  ];
}

/// « Réservé sur 4 objectifs » at 40 px, then « Épargne disponible » at
/// 20 px behind a vertical hairline (`00` §7 Summary line).
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: state.currency,
      locale: locale,
    );

    Widget item({
      required Key key,
      required String label,
      required String figure,
      required TextStyle style,
      double gap = AppSpacing.xs,
    }) => Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, style: context.textStyles.statLabel),
        SizedBox(height: gap),
        Text(figure, key: key, maxLines: 1, style: tabularNumberStyle(style)),
      ],
    );

    return IntrinsicHeight(
      key: const Key('goalsSummary'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: item(
              key: const Key('goalsSummaryReserved'),
              label: l10n.goalsSummaryReserved(state.goals.length),
              figure: money(state.allocatedTotalMinor),
              style: textTheme.displayLarge!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: SizedBox(width: 1, child: ColoredBox(color: colors.line)),
          ),
          Flexible(
            child: item(
              key: const Key('goalsSummarySavings'),
              label: l10n.goalsSummarySavings,
              // Without a savings account there is no total to state.
              figure: state.savingsAccounts.isEmpty
                  ? l10n.goalsNoValue
                  : money(state.savingsTotalMinor),
              style: textTheme.displaySmall!,
              gap: AppSpacing.xsPlus,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Vous avez réservé 2 350,00 € de plus que le total de vos comptes
/// d’épargne. » Neutral, not a warning, and dismissible: the app cannot be
/// right about which money is savings, so it states the arithmetic.
class _OverAllocationBanner extends StatelessWidget {
  const _OverAllocationBanner({required this.state, required this.onDismiss});

  final GoalsState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return InlineBanner(
      key: const Key('goalsOverAllocationBanner'),
      tone: BannerTone.info,
      message: l10n.goalsOverAllocated(
        formatAmount(
          amountMinor: state.overAllocationMinor,
          currency: state.currency,
          locale: locale,
        ),
      ),
      onDismiss: onDismiss,
      dismissTooltip: l10n.goalsDismissBanner,
    );
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({
    required this.goal,
    required this.columns,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final List<AppTableColumn> columns;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final dimmed = goal.isArchived;
    final imageRef = goal.imageRef;
    final thumbnail = imageRef == null
        ? null
        : ref.watch(goalImageProvider(imageRef)).value;
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: goal.currency,
      locale: locale,
    );

    return AppTableRow(
      key: Key('goalRow-${goal.id}'),
      columns: columns,
      twoLines: true,
      selected: selected,
      dimmed: dimmed,
      onTap: onTap,
      cells: [
        Row(
          children: [
            if (thumbnail != null) ...[
              ClipRRect(
                key: Key('goalThumbnail-${goal.id}'),
                borderRadius: BorderRadius.circular(AppRadii.item),
                child: Image.memory(
                  thumbnail,
                  width: AppGoalBanner.thumbWidth,
                  height: AppGoalBanner.thumbHeight,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: dimmed ? colors.textTertiary : colors.text,
                ),
              ),
            ),
          ],
        ),
        goal.isReached
            ? StatusText(
                key: Key('goalDeadline-${goal.id}'),
                label: goalReachedLabel(l10n, locale, goal),
                tone: StatusTone.positive,
              )
            : Text(
                goalDeadlineLabel(l10n, locale, goal),
                key: Key('goalDeadline-${goal.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: dimmed ? colors.textTertiary : colors.textSecondary,
                ),
              ),
        RepereMeter(
          key: Key('goalMeter-${goal.id}'),
          fraction: goal.barFraction,
          tone: goalRepereTone(goal),
          semanticLabel: goalPercentLabel(goal.progressPct, locale),
        ),
        Text.rich(
          key: Key('goalReserved-${goal.id}'),
          TextSpan(
            children: [
              TextSpan(text: money(goal.progressMinor)),
              TextSpan(
                text: ' ${l10n.goalsTargetSuffix(money(goal.targetMinor))}',
                style: TextStyle(color: colors.textTertiary),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: dimmed ? colors.textTertiary : colors.text),
        ),
        Text(
          goalPercentLabel(goal.progressPct, locale),
          key: Key('goalPercent-${goal.id}'),
          maxLines: 1,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: dimmed ? colors.textTertiary : colors.text),
        ),
      ],
    );
  }
}

/// `archive` 14 px + « 2 objectifs archivés », 12 `textSecondary`.
class _ArchivedLink extends StatelessWidget {
  const _ArchivedLink({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        expanded: open,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('goalsArchivedToggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons300.archive,
                  size: AppSizes.iconSmall,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xsPlus),
                Text(
                  l10n.goalsArchivedLink(count),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
