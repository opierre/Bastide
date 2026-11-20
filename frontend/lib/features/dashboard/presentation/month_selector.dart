import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_controller.dart';

/// The dashboard's title-bar control (`docs/design/04-dashboard.md` §Title bar): a 28 px
/// select-look « ‹ Mai 2026 › » (`00` §6, Select) stepping one month at a time.
///
/// The label between the chevrons opens a month-and-year picker. Stepping is
/// the fast path for "last month"; reaching a month a year back through it
/// costs a dozen clicks, which is what the picker is for.
class DashboardTopBarActions extends ConsumerWidget {
  const DashboardTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final month = ref.watch(dashboardControllerProvider).value?.month;
    final locale = Localizations.localeOf(context).toString();
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Container(
      height: AppSizes.toolbarSelect,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: context.colors.field,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: context.colors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: const Key('dashboardMonthPrev'),
            icon: LucideIcons300.chevronLeft,
            tooltip: l10n.dashboardPreviousMonth,
            onPressed: month == null
                ? null
                : () => controller.changeMonth(_shift(month, -1)),
          ),
          MonthPickerAnchor(
            month: month,
            locale: locale,
            onSelected: controller.changeMonth,
          ),
          _StepButton(
            key: const Key('dashboardMonthNext'),
            icon: LucideIcons300.chevronRight,
            tooltip: l10n.dashboardNextMonth,
            onPressed: month == null
                ? null
                : () => controller.changeMonth(_shift(month, 1)),
          ),
        ],
      ),
    );
  }
}

/// The month label, and the picker it drops.
///
/// The browsed year is local UI state rather than controller state: paging to
/// 2025 and closing the popover without choosing must not move the dashboard,
/// so the year only becomes a selection once a month is tapped.
class MonthPickerAnchor extends StatefulWidget {
  const MonthPickerAnchor({
    super.key,
    required this.month,
    required this.locale,
    required this.onSelected,
  });

  /// The selected month, or null while the dashboard is still loading.
  final DateTime? month;
  final String locale;
  final ValueChanged<DateTime> onSelected;

  @override
  State<MonthPickerAnchor> createState() => _MonthPickerAnchorState();
}

class _MonthPickerAnchorState extends State<MonthPickerAnchor> {
  final _menuController = MenuController();

  /// Null until the popover is first opened, at which point it is seeded from
  /// the current selection — and re-seeded on every open, so the picker always
  /// opens on the year the dashboard is actually showing.
  int? _browsedYear;

  void _open() {
    setState(() => _browsedYear = widget.month?.year ?? DateTime.now().year);
    _menuController.open();
  }

  void _select(int month) {
    _menuController.close();
    widget.onSelected(DateTime(_browsedYear!, month));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final month = widget.month;
    final style = Theme.of(context).textTheme.bodyMedium;
    String labelFor(DateTime value) =>
        _capitalize(DateFormat.yMMMM(widget.locale).format(value));

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, AppSpacing.sm),
      style: AppPopover.menuStyle(context, maxHeight: double.infinity),
      menuChildren: [
        if (_browsedYear case final year?)
          _PickerPanel(
            year: year,
            selected: widget.month,
            locale: widget.locale,
            onYearChanged: (value) => setState(() => _browsedYear = value),
            onMonthSelected: _select,
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: l10n.dashboardChooseMonth,
        child: InkWell(
          key: const Key('dashboardMonthPickerButton'),
          borderRadius: BorderRadius.circular(AppRadii.item),
          hoverColor: context.colors.hover,
          // Disabled while the month is unknown: the picker would have nothing
          // to open on, and the label beside it is empty anyway.
          onTap: widget.month == null ? null : _open,
          child: Container(
            constraints: const BoxConstraints(minWidth: _labelMinWidth),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xsPlus),
            // Sized to the year's widest month rather than to the one shown: « Mai 2026 » and
            // « Septembre 2026 » differ by a third, and a pill that resized on every step
            // moved the chevron out from under the pointer clicking it.
            child: month == null
                ? Text('', key: const Key('dashboardMonthLabel'), style: style)
                : IndexedStack(
                    index: month.month - 1,
                    alignment: Alignment.center,
                    children: [
                      for (var m = 1; m <= 12; m++)
                        Text(
                          labelFor(DateTime(month.year, m)),
                          key: m == month.month
                              ? const Key('dashboardMonthLabel')
                              : null,
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The popover body: a year stepper over a 3×4 grid of months.
class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.year,
    required this.selected,
    required this.locale,
    required this.onYearChanged,
    required this.onMonthSelected,
  });

  final int year;
  final DateTime? selected;
  final String locale;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Standalone month names ("janv."), not the genitive form a full date would
    // take in some locales — these label a cell, not a date.
    final monthFormat = DateFormat('LLL', locale);

    return SizedBox(
      width: 236,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StepButton(
                  key: const Key('dashboardYearPrev'),
                  icon: LucideIcons300.chevronLeft,
                  tooltip: l10n.dashboardPreviousYear,
                  onPressed: () => onYearChanged(year - 1),
                ),
                Expanded(
                  child: Text(
                    '$year',
                    key: const Key('dashboardPickerYearLabel'),
                    textAlign: TextAlign.center,
                    style: tabularNumberStyle(
                      Theme.of(context).textTheme.titleSmall!,
                    ),
                  ),
                ),
                _StepButton(
                  key: const Key('dashboardYearNext'),
                  icon: LucideIcons300.chevronRight,
                  tooltip: l10n.dashboardNextYear,
                  onPressed: () => onYearChanged(year + 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var row = 0; row < 4; row++) ...[
              if (row > 0) const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  for (var column = 0; column < 3; column++) ...[
                    if (column > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _MonthCell(
                        month: row * 3 + column + 1,
                        label: _capitalize(
                          monthFormat.format(
                            DateTime(year, row * 3 + column + 1),
                          ),
                        ),
                        isSelected:
                            selected != null &&
                            selected!.year == year &&
                            selected!.month == row * 3 + column + 1,
                        onTap: onMonthSelected,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One month in the grid, a 28 px popover item. The selection is carried by weight as well as
/// by the `accentSoft` ground, so it never rests on colour alone.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final int month;
  final String label;
  final bool isSelected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? context.colors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.item),
      child: InkWell(
        key: Key('dashboardPickerMonth-$month'),
        borderRadius: BorderRadius.circular(AppRadii.item),
        hoverColor: context.colors.hover,
        onTap: () => onTap(month),
        child: Container(
          height: AppSizes.popoverItem,
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected ? context.colors.accent : context.colors.text,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: AppSizes.iconSmall),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: AppSizes.button - AppSpacing.sm,
        minHeight: AppSizes.button - AppSpacing.sm,
      ),
    );
  }
}

/// Room for the widest month label of a year, so the control does not resize as it steps.
const _labelMinWidth = 96.0;

DateTime _shift(DateTime month, int months) =>
    DateTime(month.year, month.month + months);

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
