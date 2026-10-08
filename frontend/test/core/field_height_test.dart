import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:bastide/core/widgets/labeled_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: the dense input decorator lays its text out on the font's own
  // metrics rather than the 1.5 line height, so the 12px padding that was meant
  // to land a field on 44 landed it on 36 — visibly shorter than the select and
  // the read-only plate stacked with it in the account form.
  testWidgets(
    'a text field is the same height as the other controls in a form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(key: const Key('text')),
                    AppSelect<int>(
                      key: const Key('select'),
                      value: 1,
                      items: const [AppSelectItem(value: 1, label: 'Un')],
                      onChanged: (_) {},
                    ),
                    const ReadOnlyField(key: Key('readOnly'), value: 'EUR'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in ['text', 'select', 'readOnly']) {
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          44,
          reason: 'the $key control should stand 44px like the rest',
        );
      }
    },
  );
}
