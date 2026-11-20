import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/mortgages_controller.dart';
import '../domain/schedule_row.dart';
import 'mortgage_labels.dart';

/// « Tableau d’amortissement » (`12-credits.md` § Loan detail, block 3): the
/// heading and its line on the left, the year switcher on the right, then one
/// calendar year of the schedule.
///
/// 300 rows never appear at once. Every figure, each row and the foot's
/// totals, is the API's; insurance keeps its own column, because folding it
/// into interest or principal would misstate both.
class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({super.key, required this.years});

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

    return Column(
      key: const Key('scheduleSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mortgageScheduleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    switch (window) {
                      AsyncData(:final value) => l10n.mortgageScheduleSubtitle(
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
                      color: context.colors.textTertiary,
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
        const SizedBox(height: AppSpacing.smPlus),
        Expanded(
          child: switch (window) {
            AsyncData(:final value) => SingleChildScrollView(
              child: ScheduleTable(window: value, years: years),
            ),
            AsyncError() => ErrorStateView(
              message: l10n.mortgageScheduleLoadFailed,
              messageKey: const Key('scheduleErrorText'),
              retryLabel: l10n.mortgagesRetry,
              retryKey: const Key('scheduleRetryButton'),
              onRetry: () => ref.invalidate(scheduleWindowProvider(windowKey)),
            ),
            _ => const SkeletonList(
              key: Key('scheduleLoading'),
              itemCount: 6,
              itemHeight: AppLoans.scheduleRow,
            ),
          },
        ),
      ],
    );
  }
}

/// Secondary icon buttons `chevron-left` and `chevron-right` around the year,
/// then a select listing every year of the loan. The chevrons step one year;
/// the select jumps.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          key: const Key('yearSwitcherPrevious'),
          label: l10n.mortgageScheduleYearPrevious,
          icon: LucideIcons300.chevronLeft,
          iconOnly: true,
          onPressed: selected > years.firstYear ? () => onStep(-1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '$selected',
            key: const Key('yearSwitcherLabel'),
            style: tabularNumberStyle(textTheme.labelLarge!),
          ),
        ),
        AppButton(
          key: const Key('yearSwitcherNext'),
          label: l10n.mortgageScheduleYearNext,
          icon: LucideIcons300.chevronRight,
          iconOnly: true,
          onPressed: selected < years.lastYear ? () => onStep(1) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: AppLoans.yearSelectWidth,
          child: Semantics(
            label: l10n.mortgageScheduleYearSelect,
            child: AppSelect<int>(
              key: const Key('yearSwitcherSelect'),
              value: selected,
              height: AppSizes.toolbarSelect,
              onChanged: onSelect,
              items: [
                for (var year = years.firstYear; year <= years.lastYear; year++)
                  AppSelectItem(value: year, label: '$year'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The year's rows on dense 28 px rows under the table header of `00` §7, all
/// columns right-aligned, and the foot row at 13/600 over a `lineStrong`
/// hairline. The current instalment's row takes `accentSoft`.
class ScheduleTable extends StatelessWidget {
  const ScheduleTable({super.key, required this.window, required this.years});

  final ScheduleYear window;
  final ScheduleYears years;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final cellStyle = tabularNumberStyle(
      textTheme.bodyMedium!,
    ).copyWith(color: colors.text);
    final footStyle = cellStyle.copyWith(fontWeight: FontWeight.w600);
    final headerStyle = textTheme.bodySmall!.copyWith(
      color: colors.textTertiary,
    );

    String money(int minor) => formatAmount(
      amountMinor: minor,
      currency: window.currency,
      locale: locale,
    );

    Text cell(String text, {Key? key, TextStyle? style}) => Text(
      text,
      key: key,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? cellStyle,
    );

    return Column(
      key: const Key('scheduleTable'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _Line(
            cells: [
              for (final label in [
                l10n.mortgageScheduleDue,
                l10n.mortgageScheduleInterest,
                l10n.mortgageSchedulePrincipal,
                l10n.mortgageScheduleInsurance,
                l10n.mortgageScheduleTotalPaid,
                l10n.mortgageScheduleOutstanding,
              ])
                cell(label, style: headerStyle),
            ],
          ),
        ),
        for (final row in window.rows)
          _Line(
            key: Key('scheduleRow-${row.ordinal}'),
            height: AppLoans.scheduleRow,
            border: colors.line,
            color: years.isCurrentInstalment(row) ? colors.accentSoft : null,
            cells: [
              cell(mortgageDateFormat(locale).format(row.dueOn)),
              cell(
                money(row.interestMinor),
                key: Key('scheduleInterest-${row.ordinal}'),
              ),
              cell(
                money(row.principalMinor),
                key: Key('schedulePrincipal-${row.ordinal}'),
              ),
              cell(
                money(row.insuranceMinor),
                key: Key('scheduleInsurance-${row.ordinal}'),
              ),
              cell(
                money(row.instalmentMinor),
                key: Key('scheduleTotal-${row.ordinal}'),
              ),
              cell(
                money(row.outstandingAfterMinor),
                key: Key('scheduleOutstanding-${row.ordinal}'),
              ),
            ],
          ),
        _Line(
          key: const Key('scheduleFoot'),
          height: AppLoans.scheduleRow,
          border: colors.lineStrong,
          cells: [
            cell(
              l10n.mortgageScheduleFootTotal('${window.year}'),
              style: footStyle,
            ),
            cell(
              money(window.interestMinor),
              key: const Key('scheduleFootInterest'),
              style: footStyle,
            ),
            cell(
              money(window.principalMinor),
              key: const Key('scheduleFootPrincipal'),
              style: footStyle,
            ),
            cell(
              money(window.insuranceMinor),
              key: const Key('scheduleFootInsurance'),
              style: footStyle,
            ),
            cell(
              money(window.instalmentMinor),
              key: const Key('scheduleFootTotal'),
              style: footStyle,
            ),
            cell(
              l10n.mortgageScheduleFootOutstanding(
                mortgageDateFormat(
                  locale,
                ).format(DateTime(window.year, 12, 31)),
                money(window.outstandingAtYearEndMinor),
              ),
              key: const Key('scheduleFootOutstanding'),
              style: cellStyle.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line of the schedule: six equal columns, right-aligned, the cell
/// padding-right of `00` §7, an optional top hairline and ground.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.cells,
    this.height,
    this.border,
    this.color,
  });

  final List<Widget> cells;
  final double? height;
  final Color? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: border == null ? null : Border(top: BorderSide(color: border!)),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSpacing.smPlus,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: cell,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
