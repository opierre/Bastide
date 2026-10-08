import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({double width = 420}) {
  return MaterialApp(
    theme: appDarkTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: AppSelect<int>(
            key: const Key('select'),
            value: 1,
            items: const [
              AppSelectItem(value: 1, label: 'Un'),
              AppSelectItem(value: 2, label: 'Deux'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Regression: the width used to be asked for through [MenuStyle.minimumSize],
  // which a vertical menu panel drops on the floor — the popover came up at its
  // own intrinsic width, well short of the field, on the first open and every
  // one after it.
  testWidgets(
    'the popover is as wide as the field it drops from, from the first open',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('select')));
      await tester.pumpAndSettle();

      final anchor = tester.getRect(find.byKey(const Key('select')));
      for (final row in find.byType(MenuItemButton).evaluate()) {
        final rect = tester.getRect(find.byWidget(row.widget));
        expect(rect.left, anchor.left);
        expect(rect.width, anchor.width);
      }
    },
  );

  testWidgets(
    'an option is set in the same style as the closed field states the choice',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final closed = tester.widget<Text>(find.text('Un'));

      await tester.tap(find.byKey(const Key('select')));
      await tester.pumpAndSettle();

      final option = tester.widget<Text>(find.text('Deux'));
      expect(option.style?.fontSize, closed.style?.fontSize);
      expect(option.style?.fontFamily, closed.style?.fontFamily);
      expect(option.style?.fontWeight, closed.style?.fontWeight);
    },
  );
}
