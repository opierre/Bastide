import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// One column of a table: its header label and how it takes width.
@immutable
class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.flex = 1,
    this.width,
    this.numeric = false,
    this.sortable = false,
  });

  final String label;

  /// Share of the free width, when [width] is not set.
  final int flex;

  /// A fixed width, for a date, an amount or an action column.
  final double? width;

  /// Right-aligned, in tabular figures.
  final bool numeric;

  /// Whether the header sorts on a tap.
  final bool sortable;
}

/// The cell padding-right of `docs/design/00-design-system.md` §7.
const _cellGap = AppSpacing.smPlus;

/// Lays [cells] out under [columns]: fixed widths first, the rest shared by
/// flex, numeric columns right-aligned.
class _Cells extends StatelessWidget {
  const _Cells({required this.columns, required this.cells});

  final List<AppTableColumn> columns;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == columns.length, 'one cell per column');
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++) _cell(columns[i], cells[i]),
      ],
    );
  }

  Widget _cell(AppTableColumn column, Widget child) {
    final aligned = Padding(
      padding: const EdgeInsetsDirectional.only(end: _cellGap),
      child: Align(
        alignment: column.numeric
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: child,
      ),
    );
    final width = column.width;
    if (width != null) return SizedBox(width: width, child: aligned);
    return Expanded(flex: column.flex, child: aligned);
  }
}

/// The header of a table (`00` §7): 12/400 `textTertiary`, no ground, 8 px
/// above the first row. A sortable column shows `chevron-up` or
/// `chevron-down` (14 px) beside its label while it is the sorted one.
class AppTableHeader extends StatelessWidget {
  const AppTableHeader({
    super.key,
    required this.columns,
    this.sortColumn,
    this.ascending = true,
    this.onSort,
  });

  final List<AppTableColumn> columns;

  /// Index of the sorted column, if any.
  final int? sortColumn;
  final bool ascending;

  /// Called with a sortable column's index when its label is tapped.
  final ValueChanged<int>? onSort;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _Cells(
        columns: columns,
        cells: [
          for (var i = 0; i < columns.length; i++)
            _HeaderLabel(
              key: Key('appTableHeader-$i'),
              column: columns[i],
              style: style,
              sorted: sortColumn == i,
              ascending: ascending,
              onTap: columns[i].sortable && onSort != null
                  ? () => onSort!(i)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({
    super.key,
    required this.column,
    required this.style,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final AppTableColumn column;
  final TextStyle? style;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            column.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (sorted) ...[
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            ascending ? LucideIcons300.chevronUp : LucideIcons300.chevronDown,
            key: const Key('appTableSortIcon'),
            size: AppSizes.iconSmall,
            color: context.colors.textTertiary,
          ),
        ],
      ],
    );
    if (onTap == null) return label;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: label),
      ),
    );
  }
}

/// One row of a table (`00` §7): 36 px (48 when its first cell has two
/// lines), a `line` hairline on top, `hover` under the pointer, `accentSoft`
/// when selected. A dimmed row (cancelled, disabled, archived) sets every
/// cell in `textTertiary`; a cell that colours itself can ask
/// [AppTableRow.isDimmed].
class AppTableRow extends StatefulWidget {
  const AppTableRow({
    super.key,
    required this.columns,
    required this.cells,
    this.onTap,
    this.selected = false,
    this.dimmed = false,
    this.twoLines = false,
  });

  final List<AppTableColumn> columns;
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final bool dimmed;

  /// The 48 px row, for a first cell of two lines.
  final bool twoLines;

  /// Whether the cell at [context] sits in a dimmed row.
  static bool isDimmed(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowScope>()?.dimmed ?? false;

  @override
  State<AppTableRow> createState() => _AppTableRowState();
}

class _AppTableRowState extends State<AppTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final ground = widget.selected
        ? colors.accentSoft
        : (_hovered ? colors.hover : null);
    final textColor = widget.dimmed ? colors.textTertiary : colors.text;

    final row = Container(
      height: widget.twoLines ? AppSizes.tableRowTwoLines : AppSizes.tableRow,
      decoration: BoxDecoration(
        color: ground,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: _RowScope(
        dimmed: widget.dimmed,
        child: DefaultTextStyle.merge(
          style: tabularNumberStyle(
            textTheme.bodyMedium!,
          ).copyWith(color: textColor),
          maxLines: widget.twoLines ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          child: IconTheme.merge(
            data: IconThemeData(
              size: AppSizes.iconSmall,
              color: widget.dimmed ? colors.textTertiary : colors.textSecondary,
            ),
            child: _Cells(columns: widget.columns, cells: widget.cells),
          ),
        ),
      ),
    );

    return Semantics(
      selected: widget.selected,
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

class _RowScope extends InheritedWidget {
  const _RowScope({required this.dimmed, required super.child});

  final bool dimmed;

  @override
  bool updateShouldNotify(_RowScope oldWidget) => oldWidget.dimmed != dimmed;
}

/// A row spanning the table that groups the rows beneath it (`00` §7): a day,
/// an account type. 30 px, `rail` ground, 12 `textTertiary`, with an
/// optional right-aligned [trailing] (the group's total).
class AppTableGroupRow extends StatelessWidget {
  const AppTableGroupRow({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = tabularNumberStyle(
      Theme.of(context).textTheme.bodySmall!,
    ).copyWith(color: colors.textTertiary);

    return Container(
      height: AppSizes.groupRow,
      padding: const EdgeInsetsDirectional.only(end: _cellGap),
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: DefaultTextStyle.merge(
        style: style,
        child: Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
