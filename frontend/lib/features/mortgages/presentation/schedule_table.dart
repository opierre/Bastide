import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/schedule_row.dart';
import 'mortgage_labels.dart';

/// « Tableau d'amortissement » (`12-credits.md` frame ②): one calendar year of
/// the schedule at a time, paged by the YearSwitcher.
///
/// 300 rows never appear at once. Every figure — each row, and the foot's
/// totals — is the API's; insurance keeps its own column, because folding it
/// into interest or principal would misstate both.
class ScheduleTableCard extends ConsumerWidget {
  const ScheduleTableCard({super.key, required this.years});

  final ScheduleYears years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final yearProvider = scheduleYearControllerProvider(years);
    final year = ref.watch(yearProvider);
    final windowKey = (mortgageId: years.mortgageId, year: year);
    final window = ref.watch(scheduleWindowProvider(windowKey));
    final position = years.positionOf(year);

    return AppCard(
      key: const Key('scheduleTableCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mortgageScheduleTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      switch (window) {
                        AsyncData(:final value) =>
                          l10n.mortgageScheduleSubtitle(
                            position,
                            years.yearCount,
                            value.rows.length,
                          ),
                        _ => l10n.mortgageScheduleSubtitleLoading(
                          position,
                          years.yearCount,
                        ),
                      },
                      key: const Key('scheduleSubtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              YearSwitcher(
                years: years,
                selected: year,
                onStep: ref.read(yearProvider.notifier).step,
                onSelect: ref.read(yearProvider.notifier).select,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: switch (window) {
              AsyncData(:final value) => ScheduleTable(
                window: value,
                years: years,
              ),
              AsyncError() => ErrorStateView(
                message: l10n.mortgageScheduleLoadFailed,
                messageKey: const Key('scheduleErrorText'),
                retryLabel: l10n.mortgagesRetry,
                retryKey: const Key('scheduleRetryButton'),
                onRetry: () =>
                    ref.invalidate(scheduleWindowProvider(windowKey)),
              ),
              _ => const SkeletonList(
                key: Key('scheduleLoading'),
                itemCount: 6,
                itemHeight: ScheduleTable.rowHeight,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// The ‹ 2026 › pill beside a segmented strip of the loan's years.
///
/// The chevrons step one year; the strip jumps. The strip shows a five-year
/// window around the selection and a disabled « … 2048 » tail naming the last
/// year, so a 25-year loan never becomes a 25-segment control.
class YearSwitcher extends StatelessWidget {
  const YearSwitcher({
    super.key,
    required this.years,
    required this.selected,
    required this.onStep,
    required this.onSelect,
  });

  final ScheduleYears years;
  final int selected;
  final ValueChanged<int> onStep;
  final ValueChanged<int> onSelect;

  static const _stripLength = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final lastStart = years.lastYear - _stripLength + 1;
    final start = (selected - 3).clamp(
      years.firstYear,
      lastStart < years.firstYear ? years.firstYear : lastStart,
    );
    final end = (start + _stripLength - 1).clamp(
      years.firstYear,
      years.lastYear,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepButton(
                key: const Key('yearSwitcherPrevious'),
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.mortgageScheduleYearPrevious,
                onPressed: selected > years.firstYear ? () => onStep(-1) : null,
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$selected',
                  key: const Key('yearSwitcherLabel'),
                  textAlign: TextAlign.center,
                  style: tabularNumberStyle(textTheme.bodyMedium!),
                ),
              ),
              _StepButton(
                key: const Key('yearSwitcherNext'),
                icon: Icons.chevron_right_rounded,
                tooltip: l10n.mortgageScheduleYearNext,
                onPressed: selected < years.lastYear ? () => onStep(1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceField,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var year = start; year <= end; year++)
                _YearCell(
                  year: year,
                  selected: year == selected,
                  onTap: () => onSelect(year),
                ),
              if (end < years.lastYear)
                Padding(
                  key: const Key('yearSwitcherTail'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Center(
                    child: Text(
                      '… ${years.lastYear}',
                      style: tabularNumberStyle(
                        textTheme.bodySmall!,
                      ).copyWith(color: AppColors.textDisabled),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    );
  }
}

class _YearCell extends StatelessWidget {
  const _YearCell({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.irisSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        key: Key('yearSwitcherYear-$year'),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        hoverColor: AppColors.overlayWash,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
          child: Center(
            child: Text(
              '$year',
              style: tabularNumberStyle(Theme.of(context).textTheme.bodySmall!)
                  .copyWith(
                    color: selected ? AppColors.iris : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The year's rows on the dense 28 px variant, under a 30 px header and over a
/// 34 px foot — twelve rows and the foot fit a 900 px frame without scrolling.
class ScheduleTable extends StatelessWidget {
  const ScheduleTable({super.key, required this.window, required this.years});

  final ScheduleYear window;
  final ScheduleYears years;

  static const headerHeight = 30.0;
  static const rowHeight = 28.0;
  static const footHeight = 34.0;

  /// The current instalment's wash — iris at 6 %.
  static const _currentWash = Color(0x0F8B8CF9);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final cellStyle = tabularNumberStyle(textTheme.bodySmall!);
    final footStyle = cellStyle.copyWith(fontWeight: FontWeight.w700);
    final headerStyle = AppTextStyles.sectionLabel.copyWith(
      fontSize: 10.5,
      letterSpacing: 1,
    );

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: window.currency,
      locale: locale,
    );

    return Column(
      key: const Key('scheduleTable'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(
          height: headerHeight,
          color: AppColors.surfaceRowHover,
          cells: [
            for (final label in [
              l10n.mortgageScheduleDue,
              l10n.mortgageScheduleInterest,
              l10n.mortgageSchedulePrincipal,
              l10n.mortgageScheduleInsurance,
              l10n.mortgageScheduleTotalPaid,
              l10n.mortgageScheduleOutstanding,
            ])
              Text(label.toUpperCase(), style: headerStyle),
          ],
        ),
        for (final row in window.rows)
          _row(row, years.isCurrentInstalment(row), cellStyle, money, locale),
        _Line(
          key: const Key('scheduleFoot'),
          height: footHeight,
          color: AppColors.surfaceRowHover,
          cells: [
            Text(
              l10n.mortgageScheduleFootTotal('${window.year}'),
              style: footStyle,
            ),
            Text(
              money(window.interestMinor),
              key: const Key('scheduleFootInterest'),
              style: footStyle,
            ),
            Text(
              money(window.principalMinor),
              key: const Key('scheduleFootPrincipal'),
              style: footStyle,
            ),
            Text(
              money(window.insuranceMinor),
              key: const Key('scheduleFootInsurance'),
              style: footStyle,
            ),
            Text(
              money(window.instalmentMinor),
              key: const Key('scheduleFootTotal'),
              style: footStyle,
            ),
            Text(
              l10n.mortgageScheduleFootOutstanding(
                mortgageDateFormat(
                  locale,
                ).format(DateTime(window.year, 12, 31)),
                money(window.outstandingAtYearEndMinor),
              ),
              key: const Key('scheduleFootOutstanding'),
              style: cellStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(
    ScheduleRow row,
    bool isCurrent,
    TextStyle style,
    String Function(int) money,
    String locale,
  ) {
    final id = row.ordinal;
    final emphasis = isCurrent
        ? style.copyWith(fontWeight: FontWeight.w700)
        : style;
    return _Line(
      key: Key('scheduleRow-$id'),
      height: rowHeight,
      color: isCurrent ? _currentWash : null,
      divider: true,
      cells: [
        Text(
          mortgageDateFormat(locale).format(row.dueOn),
          style: isCurrent
              ? style.copyWith(
                  color: AppColors.iris,
                  fontWeight: FontWeight.w700,
                )
              : style,
        ),
        Text(
          money(row.interestMinor),
          key: Key('scheduleInterest-$id'),
          style: style,
        ),
        Text(
          money(row.principalMinor),
          key: Key('schedulePrincipal-$id'),
          style: style,
        ),
        Text(
          money(row.insuranceMinor),
          key: Key('scheduleInsurance-$id'),
          style: style,
        ),
        Text(
          money(row.instalmentMinor),
          key: Key('scheduleTotal-$id'),
          style: style,
        ),
        Text(
          money(row.outstandingAfterMinor),
          key: Key('scheduleOutstanding-$id'),
          style: emphasis,
        ),
      ],
    );
  }
}

/// One table line: the 150 px date column, four equal amount columns and the
/// 1.3fr outstanding column, amounts right-aligned.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.height,
    required this.cells,
    this.color,
    this.divider = false,
  });

  final double height;
  final List<Widget> cells;
  final Color? color;
  final bool divider;

  static const _flexes = [10, 10, 10, 10, 13];

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget child, {required bool alignEnd}) => Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.borderSubtle))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 150, child: cell(cells.first, alignEnd: false)),
          for (var index = 1; index < cells.length; index++)
            Expanded(
              flex: _flexes[index - 1],
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: cell(cells[index], alignEnd: true),
              ),
            ),
        ],
      ),
    );
  }
}
