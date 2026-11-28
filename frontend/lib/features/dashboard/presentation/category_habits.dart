import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_habits_provider.dart';
import '../domain/dashboard_habits.dart';

/// « Par rapport à vos habitudes » as the dashboard mounts it: the block once
/// its data is in, its own silhouette while it loads, its own error state if
/// the call fails, so the rest of the panel stays readable.
class DashboardHabitsBlock extends ConsumerWidget {
  const DashboardHabitsBlock({super.key, required this.onCategoryTap});

  /// Opens Transactions on a row's category over the habits' month.
  final void Function(String? categoryId, DateTime month) onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return switch (ref.watch(dashboardHabitsProvider)) {
      AsyncData(:final value) => CategoryHabits(
        habits: value,
        onCategoryTap: (categoryId) => onCategoryTap(categoryId, value.month),
      ),
      AsyncError() => ErrorStateView(
        message: l10n.dashboardHabitsError,
        retryLabel: l10n.dashboardRetry,
        retryKey: const Key('dashboardHabitsRetryButton'),
        onRetry: () => ref.invalidate(dashboardHabitsProvider),
      ),
      _ => const SkeletonPulse(
        key: Key('dashboardHabitsLoading'),
        child: SkeletonBlock(height: double.infinity),
      ),
    };
  }
}

/// « Par rapport à vos habitudes » (`docs/design/04-dashboard.md` §5a): each
/// category's spending this month against its own average. The total gap on
/// the heading line; a Note when the month is still in progress; then a
/// table whose header labels the repère column once, and one 36 px row per
/// category: label · repère (scale 0 to twice the average, the mark at the
/// average, `over` from 120 %) · the month's amount · the gap.
///
/// As many rows as the height allows, at most eight; the API already orders
/// them largest gap first, the rows without history last.
class CategoryHabits extends StatelessWidget {
  const CategoryHabits({
    super.key,
    required this.habits,
    required this.onCategoryTap,
  });

  final DashboardHabits habits;

  /// Opens Transactions on the row's category; `null` for the uncategorized
  /// bucket.
  final ValueChanged<String?> onCategoryTap;

  /// The columns (`04` §5a).
  static const labelWidth = 130.0;
  static const amountWidth = 90.0;
  static const gapWidth = 96.0;

  static const _columns = [
    AppTableColumn(label: '', width: labelWidth),
    AppTableColumn(label: ''),
    AppTableColumn(label: '', width: amountWidth, numeric: true),
    AppTableColumn(label: '', width: gapWidth, numeric: true),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final rows = habits.shownRows;
    final monthName = _capitalize(DateFormat.MMMM(locale).format(habits.month));

    return Column(
      key: const Key('dashboardHabits'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: l10n.dashboardHabitsTitle,
          trailing: switch (habits.totalGapMinor) {
            null => null,
            final total => Text(
              _totalLabel(l10n, total, locale),
              key: const Key('dashboardHabitsTotal'),
              maxLines: 1,
              style: tabularNumberStyle(
                textTheme.bodyMedium!,
              ).copyWith(color: colors.textSecondary),
            ),
          },
        ),
        if (habits.daysElapsed case final days?) ...[
          NoteLine(
            key: const Key('dashboardHabitsInProgress'),
            icon: LucideIcons300.calendarClock,
            text: l10n.dashboardHabitsInProgress(monthName, days),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (rows.isEmpty)
          NoteLine(
            key: const Key('dashboardHabitsEmpty'),
            text: l10n.dashboardCategoryNoSpending,
          )
        else ...[
          _HeaderRow(
            averageLabel: habits.monthsCounted > 0
                ? l10n.dashboardHabitsAverageOver(habits.monthsCounted)
                : '',
            monthLabel: monthName,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fits = constraints.hasBoundedHeight
                    ? constraints.maxHeight ~/ AppSizes.tableRow
                    : rows.length;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in rows.take(fits))
                      _HabitRow(
                        row: row,
                        currency: habits.currency,
                        columns: _columns,
                        onTap: () => onCategoryTap(row.categoryId),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// « 102,99 € de plus que votre moyenne », the amount unsigned.
  String _totalLabel(AppLocalizations l10n, int total, String locale) {
    final amount = formatAmount(
      amountMinor: total.abs(),
      currency: habits.currency,
      locale: locale,
    );
    return switch (total) {
      > 0 => l10n.dashboardHabitsMore(amount),
      < 0 => l10n.dashboardHabitsLess(amount),
      _ => l10n.dashboardHabitsSame,
    };
  }
}

/// The header row: 12 `textTertiary` labels, except the repère column's,
/// 11 `textSecondary` and centred on the track, where it labels the marks of
/// the whole column. Cells padded as [AppTableRow]'s, so the labels stand
/// over their columns.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.averageLabel, required this.monthLabel});

  final String averageLabel;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodySmall?.copyWith(color: colors.textTertiary);

    Widget cell(Widget child, {double? width, bool end = false}) {
      final padded = Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.smPlus),
        child: Align(
          alignment: end
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: child,
        ),
      );
      return width == null
          ? Expanded(child: padded)
          : SizedBox(width: width, child: padded);
    }

    Text label(String text, {Key? key}) =>
        Text(text, key: key, maxLines: 1, style: style);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          cell(
            label(l10n.dashboardHabitsCategory),
            width: CategoryHabits.labelWidth,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.smPlus),
              child: Text(
                averageLabel,
                key: const Key('dashboardHabitsAverageHeader'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          cell(
            label(monthLabel, key: const Key('dashboardHabitsMonthHeader')),
            width: CategoryHabits.amountWidth,
            end: true,
          ),
          cell(
            label(l10n.dashboardHabitsGap),
            width: CategoryHabits.gapWidth,
            end: true,
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.row,
    required this.currency,
    required this.columns,
    required this.onTap,
  });

  final CategoryHabit row;
  final String currency;
  final List<AppTableColumn> columns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final id = row.categoryId ?? 'uncategorized';
    final name = localizedCategoryName(l10n, row.name);
    final label = row.categoryId == null
        ? CategoryLabel.uncategorized(label: name)
        : CategoryLabel.slotted(
            label: name,
            slot: CategorySlot.fromWire(row.hue),
          );
    final gap = row.gapMinor;

    return AppTableRow(
      key: Key('dashboardHabitRow-$id'),
      columns: columns,
      onTap: onTap,
      cells: [
        label,
        if (row.hasHistory)
          RepereMeter(
            key: Key('dashboardHabitMeter-$id'),
            fraction: row.meterFraction,
            tone: row.isOver ? RepereTone.over : RepereTone.normal,
            markFraction: CategoryHabit.averageMarkFraction,
            reserveLabelSpace: false,
            semanticLabel: formatAmount(
              amountMinor: row.averageMinor!,
              currency: currency,
              locale: locale,
            ),
          )
        else
          Text(
            l10n.dashboardHabitsNoHistory,
            key: Key('dashboardHabitNoHistory-$id'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
          ),
        AmountText(
          key: Key('dashboardHabitAmount-$id'),
          amountMinor: row.amountMinor,
          currency: currency,
          colorize: false,
          maxLines: 1,
          style: textTheme.bodyMedium,
        ),
        if (gap == null)
          Text(
            l10n.dashboardNoValue,
            key: Key('dashboardHabitGap-$id'),
            style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
          )
        else
          StatusText(
            key: Key('dashboardHabitGap-$id'),
            label: formatAmount(
              amountMinor: gap.abs(),
              currency: currency,
              locale: locale,
            ),
            // A rise in spending is bad news, a fall good news; the icon
            // carries the direction, so the amount stays unsigned.
            tone: switch (row.trend) {
              HabitTrend.rise => StatusTone.negative,
              HabitTrend.fall => StatusTone.positive,
              HabitTrend.flat => StatusTone.neutral,
            },
            icon: switch (row.trend) {
              HabitTrend.rise => LucideIcons300.trendingUp,
              HabitTrend.fall => LucideIcons300.trendingDown,
              HabitTrend.flat => LucideIcons300.minus,
            },
          ),
      ],
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
