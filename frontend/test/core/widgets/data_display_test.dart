import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/core/widgets/key_value_list.dart';
import 'package:bastide/core/widgets/section_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

const dark = AppColors.dark;

const columns = [
  AppTableColumn(label: 'Libellé', flex: 3, sortable: true),
  AppTableColumn(label: 'Montant', width: 120, numeric: true, sortable: true),
];

Widget table(Widget child) => SizedBox(width: 600, child: child);

AppTableRow row({
  bool selected = false,
  bool dimmed = false,
  bool twoLines = false,
  VoidCallback? onTap,
}) => AppTableRow(
  key: const Key('row'),
  columns: columns,
  selected: selected,
  dimmed: dimmed,
  twoLines: twoLines,
  onTap: onTap,
  cells: const [Text('Boulangerie du port'), Text('12,40 €')],
);

Color? groundOfRow(WidgetTester tester) =>
    firstDecorationUnder(tester, find.byKey(const Key('row'))).color;

void main() {
  group('AppTableRow', () {
    testWidgets('a row is 36 px with a top line hairline, 48 with two '
        'lines', (tester) async {
      await pumpHost(tester, table(row()));
      expect(tester.getSize(find.byKey(const Key('row'))).height, 36);
      final deco = firstDecorationUnder(tester, find.byKey(const Key('row')));
      expect((deco.border! as Border).top.color, dark.line);
      expect(deco.color, isNull);

      await pumpHost(tester, table(row(twoLines: true)));
      expect(tester.getSize(find.byKey(const Key('row'))).height, 48);
    });

    testWidgets('hover takes the hover ground', (tester) async {
      await pumpHost(tester, table(row(onTap: () {})));
      await hover(tester, find.byKey(const Key('row')));
      expect(groundOfRow(tester), dark.hover);
    });

    testWidgets('selected takes accentSoft', (tester) async {
      await pumpHost(tester, table(row(selected: true)));
      expect(groundOfRow(tester), dark.accentSoft);
    });

    testWidgets('dimmed sets every cell in textTertiary', (tester) async {
      await pumpHost(tester, table(row(dimmed: true)));
      for (final label in ['Boulangerie du port', '12,40 €']) {
        final style = DefaultTextStyle.of(
          tester.element(find.text(label)),
        ).style;
        expect(style.color, dark.textTertiary, reason: label);
      }
      expect(
        AppTableRow.isDimmed(tester.element(find.text('12,40 €'))),
        isTrue,
      );

      await pumpHost(tester, table(row()));
      expect(
        DefaultTextStyle.of(tester.element(find.text('12,40 €'))).style.color,
        dark.text,
      );
    });

    testWidgets('a numeric cell is right-aligned against the cell gap', (
      tester,
    ) async {
      await pumpHost(tester, table(row()));
      final rowRect = tester.getRect(find.byKey(const Key('row')));
      final amount = tester.getRect(find.text('12,40 €'));
      expect(amount.right, rowRect.right - AppSpacing.smPlus);
    });

    testWidgets('a tap calls back', (tester) async {
      var taps = 0;
      await pumpHost(tester, table(row(onTap: () => taps++)));
      await tester.tap(find.byKey(const Key('row')));
      expect(taps, 1);
    });
  });

  group('AppTableHeader', () {
    testWidgets('labels in 12 textTertiary; the sorted column shows its '
        'chevron, a tap sorts', (tester) async {
      int? sorted;
      await pumpHost(
        tester,
        table(
          AppTableHeader(
            columns: columns,
            sortColumn: 1,
            ascending: false,
            onSort: (i) => sorted = i,
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('Libellé'));
      expect(label.style?.fontSize, 12);
      expect(label.style?.color, dark.textTertiary);

      final icon = find.byKey(const Key('appTableSortIcon'));
      expect(icon, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('appTableHeader-1')),
          matching: icon,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Libellé'));
      expect(sorted, 0);
    });

    testWidgets('an unsorted header draws no chevron', (tester) async {
      await pumpHost(tester, table(const AppTableHeader(columns: columns)));
      expect(find.byKey(const Key('appTableSortIcon')), findsNothing);
    });
  });

  testWidgets('a group row is 30 px on rail in 12 textTertiary', (
    tester,
  ) async {
    await pumpHost(
      tester,
      table(
        const AppTableGroupRow(
          key: Key('group'),
          label: 'Lundi 4 mai',
          trailing: Text('−58,20 €'),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('group'))).height, 30);
    expect(
      firstDecorationUnder(tester, find.byKey(const Key('group'))).color,
      dark.rail,
    );
    final style = DefaultTextStyle.of(
      tester.element(find.text('Lundi 4 mai')),
    ).style;
    expect(style.fontSize, 12);
    expect(style.color, dark.textTertiary);
  });

  testWidgets('a key/value list sets labels in textSecondary, values '
      'right-aligned, rows 8 px apart', (tester) async {
    await pumpHost(
      tester,
      const SizedBox(
        width: 300,
        child: KeyValueList(
          entries: [KeyValue('Taux', '3,10 %'), KeyValue('Durée', '20 ans')],
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Taux')).style?.color,
      dark.textSecondary,
    );
    final list = tester.getRect(find.byType(KeyValueList));
    expect(tester.getRect(find.text('3,10 %')).right, list.right);
    final gap =
        tester.getRect(find.text('Durée')).top -
        tester.getRect(find.text('Taux')).bottom;
    expect(gap, AppSpacing.sm);
  });

  testWidgets('a section heading is 13/600 with its right side on the '
      'same line', (tester) async {
    await pumpHost(
      tester,
      const SizedBox(
        width: 400,
        child: SectionHeading(title: 'Dépenses', trailing: Text('Voir tout')),
      ),
    );
    final title = tester.widget<Text>(find.text('Dépenses'));
    final style = DefaultTextStyle.of(
      tester.element(find.text('Dépenses')),
    ).style.merge(title.style);
    expect(style.fontSize, 13);
    expect(style.fontWeight, FontWeight.w600);
    expect(
      tester.getCenter(find.text('Voir tout')).dy,
      tester.getCenter(find.text('Dépenses')).dy,
    );
  });
}
