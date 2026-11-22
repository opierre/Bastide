import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// One row of a [KeyValueList]. [value] is a string, set in `text` with
/// tabular figures, or [valueWidget] for an amount or a status.
@immutable
class KeyValue {
  const KeyValue(this.label, String this.value, {this.key})
    : valueWidget = null;

  const KeyValue.widget(this.label, Widget this.valueWidget, {this.key})
    : value = null;

  final String label;
  final String? value;
  final Widget? valueWidget;
  final Key? key;
}

/// One row of a [KeyValueComparison]: a label and one value per source, in
/// the order of the comparison's headers.
@immutable
class KeyValues {
  const KeyValues(this.label, this.values, {this.key});

  final String label;
  final List<String> values;
  final Key? key;
}

/// The comparison form of the key/value list (`00` §7): one value column per
/// source, 24 px apart, each headed 12 `textTertiary` right-aligned
/// (« Sauvegarde · Actuel »). Values stay `text` with tabular figures; a
/// difference is not coloured. Rows 8 px apart.
class KeyValueComparison extends StatelessWidget {
  const KeyValueComparison({
    super.key,
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<KeyValues> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final headerStyle = textTheme.bodySmall?.copyWith(
      color: colors.textTertiary,
    );
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: colors.textSecondary,
    );
    final valueStyle = tabularNumberStyle(
      textTheme.bodyMedium!,
    ).copyWith(color: colors.text);

    // Each value column follows a fixed 24 px gutter column, so the label
    // takes the rest and the values line up across rows.
    const gutter = SizedBox(width: AppSpacing.lg);
    Widget cell(Widget child, {required bool first}) => Padding(
      padding: EdgeInsets.only(top: first ? 0 : AppSpacing.sm),
      child: child,
    );

    TableRow row({
      required Widget label,
      required List<Widget> values,
      required bool first,
    }) => TableRow(
      children: [
        cell(label, first: first),
        for (final value in values) ...[
          gutter,
          cell(
            Align(alignment: AlignmentDirectional.centerEnd, child: value),
            first: first,
          ),
        ],
      ],
    );

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      columnWidths: {
        0: const FlexColumnWidth(),
        for (var i = 0; i < headers.length; i++) ...{
          2 * i + 1: const FixedColumnWidth(AppSpacing.lg),
          2 * i + 2: const IntrinsicColumnWidth(),
        },
      },
      children: [
        row(
          label: const SizedBox.shrink(),
          values: [
            for (final header in headers)
              Text(header, textAlign: TextAlign.end, style: headerStyle),
          ],
          first: true,
        ),
        for (final entry in rows)
          row(
            // The row's key marks its label, so a test finds the row.
            label: Text(entry.label, key: entry.key, style: labelStyle),
            values: [
              for (final value in entry.values)
                Text(value, textAlign: TextAlign.end, style: valueStyle),
            ],
            first: false,
          ),
      ],
    );
  }
}

/// The key/value list of `docs/design/00-design-system.md` §7: two columns,
/// the label in `textSecondary` on the left, the value right-aligned, rows
/// 8 px apart.
class KeyValueList extends StatelessWidget {
  const KeyValueList({super.key, required this.entries});

  final List<KeyValue> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );
    final valueStyle = tabularNumberStyle(textTheme.bodyMedium!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            key: entries[i].key,
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(entries[i].label, style: labelStyle)),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child:
                        entries[i].valueWidget ??
                        Text(
                          entries[i].value!,
                          textAlign: TextAlign.end,
                          style: valueStyle,
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
