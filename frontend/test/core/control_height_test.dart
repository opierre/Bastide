import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/app_select.dart';
import 'package:bastide/core/widgets/labeled_field.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: « Annuler » was sized from its own label — vertical padding plus
  // the font's line height — and then wrapped in Material's 48px padded tap
  // target, so it stood taller than the « Appliquer » beside it and sat off its
  // centre line, in modal footers and in plain action rows alike.
  const cancel = Key('cancel');
  const confirm = Key('confirm');

  void expectAligned(WidgetTester tester) {
    final cancelBox = tester.getRect(find.byKey(cancel));
    final confirmBox = tester.getRect(find.byKey(confirm));

    expect(cancelBox.height, AppChrome.buttonHeight);
    expect(confirmBox.height, AppChrome.buttonHeight);
    expect(cancelBox.center.dy, confirmBox.center.dy);
  }

  Widget host(Widget child) => MaterialApp(
    theme: appDarkTheme,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a modal footer stands its cancel level with its confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppModal(
          title: 'Période',
          width: 420,
          actions: [
            OutlinedButton(
              key: cancel,
              onPressed: () {},
              child: const Text('Annuler'),
            ),
            PrimaryButton(key: confirm, label: 'Appliquer', onPressed: () {}),
          ],
          child: const SizedBox(height: 40),
        ),
      ),
    );

    expectAligned(tester);
  });

  testWidgets('a ghost cancel stands level with its confirm too', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppModal(
          title: 'Compte',
          width: 480,
          actions: [
            TextButton(
              key: cancel,
              onPressed: () {},
              child: const Text('Annuler'),
            ),
            PrimaryButton(key: confirm, label: 'Enregistrer', onPressed: () {}),
          ],
          child: const SizedBox(height: 40),
        ),
      ),
    );

    expectAligned(tester);
  });

  testWidgets('a confirm dialog outside the modal shell aligns as well', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AlertDialog(
          title: const Text('Archiver ?'),
          actions: [
            TextButton(
              key: cancel,
              onPressed: () {},
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: confirm,
              onPressed: () {},
              child: const Text('Archiver'),
            ),
          ],
        ),
      ),
    );

    expectAligned(tester);
  });

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
