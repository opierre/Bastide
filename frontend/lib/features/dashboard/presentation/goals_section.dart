import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../../goals/domain/goal.dart';

/// « Objectifs » (`docs/design/04-dashboard.md` §5b): a table without header,
/// up to four active goals by creation order.
///
/// [compact] when it shares the right half with « À venir »: 48 px rows of
/// two lines, 2 px apart, the name and the percent over the repère and
/// « saved / target ». Otherwise it holds the whole right half in 36 px
/// one-line rows: name 150 px · repère · « saved / target » 190 px · percent
/// 44 px. The repère is `done` once the goal is reached.
///
/// A read-only window onto the goals panel. The caller hides the section when
/// the user has no active goal.
class GoalsSection extends StatelessWidget {
  const GoalsSection({
    super.key,
    required this.goals,
    required this.onViewAll,
    required this.onOpen,
    this.compact = false,
  });

  /// Already narrowed by `GoalsState.topGoals`.
  final List<Goal> goals;

  /// « Tous les objectifs »: opens Objectifs.
  final VoidCallback onViewAll;

  /// Opens Objectifs with the row's goal selected.
  final ValueChanged<String> onOpen;

  /// The two-line rows of the band's quarter width.
  final bool compact;

  /// The one-line columns (`04` « États »).
  static const nameWidth = 150.0;
  static const amountsWidth = 190.0;
  static const percentWidth = 44.0;

  static const _wideColumns = [
    AppTableColumn(label: '', width: nameWidth),
    AppTableColumn(label: ''),
    AppTableColumn(label: '', width: amountsWidth, numeric: true),
    AppTableColumn(label: '', width: percentWidth, numeric: true),
  ];

  /// One cell holding both lines.
  static const _compactColumns = [AppTableColumn(label: '')];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      key: const Key('dashboardGoals'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardGoalsTitle,
          trailing: AppLink(
            key: const Key('dashboardGoalsViewAll'),
            label: l10n.dashboardGoalsViewAll,
            onTap: onViewAll,
          ),
        ),
        for (final goal in goals)
          compact
              ? _CompactGoalRow(goal: goal, onTap: () => onOpen(goal.id))
              : _WideGoalRow(goal: goal, onTap: () => onOpen(goal.id)),
      ],
    );
  }
}

/// The pieces both row shapes draw, formatted for the locale.
class _GoalCells {
  _GoalCells(BuildContext context, this.goal)
    : _l10n = AppLocalizations.of(context)!,
      _locale = Localizations.localeOf(context).toString(),
      _colors = context.colors;

  final Goal goal;
  final AppLocalizations _l10n;
  final String _locale;
  final AppColors _colors;

  String get percent => NumberFormat.percentPattern(
    _locale,
  ).format(goal.progressPct).replaceAll('-', '−');

  String _money(int minor) => formatAmount(
    amountMinor: minor,
    currency: goal.currency,
    locale: _locale,
  );

  Widget name() =>
      Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis);

  Widget meter() => RepereMeter(
    key: Key('dashboardGoalMeter-${goal.id}'),
    fraction: goal.barFraction,
    tone: goal.isReached ? RepereTone.done : RepereTone.normal,
    semanticLabel: percent,
  );

  /// « saved / target » in `textSecondary`, the « / target » in
  /// `textTertiary`.
  Widget amounts(TextStyle base) => Text.rich(
    key: Key('dashboardGoalAmounts-${goal.id}'),
    TextSpan(
      children: [
        TextSpan(text: _money(goal.progressMinor)),
        TextSpan(
          text: ' ${_l10n.dashboardGoalsTarget(_money(goal.targetMinor))}',
          style: TextStyle(color: _colors.textTertiary),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: tabularNumberStyle(base).copyWith(color: _colors.textSecondary),
  );

  Widget percentText() =>
      Text(percent, key: Key('dashboardGoalPercent-${goal.id}'), maxLines: 1);
}

class _WideGoalRow extends StatelessWidget {
  const _WideGoalRow({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cells = _GoalCells(context, goal);
    return AppTableRow(
      key: Key('dashboardGoalRow-${goal.id}'),
      columns: GoalsSection._wideColumns,
      onTap: onTap,
      cells: [
        cells.name(),
        cells.meter(),
        cells.amounts(Theme.of(context).textTheme.bodyMedium!),
        cells.percentText(),
      ],
    );
  }
}

class _CompactGoalRow extends StatelessWidget {
  const _CompactGoalRow({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cells = _GoalCells(context, goal);
    return AppTableRow(
      key: Key('dashboardGoalRow-${goal.id}'),
      columns: GoalsSection._compactColumns,
      twoLines: true,
      onTap: onTap,
      cells: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: cells.name()),
                const SizedBox(width: AppSpacing.smPlus),
                cells.percentText(),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(child: cells.meter()),
                const SizedBox(width: AppSpacing.smPlus),
                cells.amounts(Theme.of(context).textTheme.bodySmall!),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
