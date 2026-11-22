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
/// up to four active goals by creation order. Each row: the name, the repère
/// (`done` once reached), « saved / target » and the percent.
///
/// A read-only window onto the goals panel. The caller hides the section when
/// the user has no active goal.
class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key, required this.goals, required this.onViewAll});

  /// Already narrowed by `GoalsState.topGoals`.
  final List<Goal> goals;
  final VoidCallback onViewAll;

  static const _columns = [
    AppTableColumn(label: '', width: 150),
    AppTableColumn(label: ''),
    AppTableColumn(label: '', width: 190, numeric: true),
    AppTableColumn(label: '', width: 56, numeric: true),
  ];

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
        for (final goal in goals) _GoalRow(goal: goal, columns: _columns),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.columns});

  final Goal goal;
  final List<AppTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final percent = NumberFormat.percentPattern(
      locale,
    ).format(goal.progressPct).replaceAll('-', '−');
    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: goal.currency,
      locale: locale,
    );

    return AppTableRow(
      key: Key('dashboardGoalRow-${goal.id}'),
      columns: columns,
      cells: [
        Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        RepereMeter(
          key: Key('dashboardGoalMeter-${goal.id}'),
          fraction: goal.barFraction,
          tone: goal.isReached ? RepereTone.done : RepereTone.normal,
          semanticLabel: percent,
        ),
        Text.rich(
          key: Key('dashboardGoalAmounts-${goal.id}'),
          TextSpan(
            children: [
              TextSpan(text: money(goal.progressMinor)),
              // « / target » in `textTertiary`, after a space.
              TextSpan(
                text: ' ${l10n.dashboardGoalsTarget(money(goal.targetMinor))}',
                style: TextStyle(color: colors.textTertiary),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: colors.textSecondary),
        ),
        Text(percent, key: Key('dashboardGoalPercent-${goal.id}'), maxLines: 1),
      ],
    );
  }
}
