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
