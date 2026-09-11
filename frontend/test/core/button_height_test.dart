import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/app_modal.dart';
import 'package:finstride/core/widgets/primary_button.dart';
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

  Widget host(Widget child) =>
      MaterialApp(theme: appDarkTheme, home: Scaffold(body: Center(child: child)));

  testWidgets('a modal footer stands its cancel level with its confirm', (tester) async {
    await tester.pumpWidget(
      host(
        AppModal(
          title: 'Période',
          width: 420,
          actions: [
            OutlinedButton(key: cancel, onPressed: () {}, child: const Text('Annuler')),
            PrimaryButton(key: confirm, label: 'Appliquer', onPressed: () {}),
          ],
          child: const SizedBox(height: 40),
        ),
      ),
    );

    expectAligned(tester);
  });

  testWidgets('a ghost cancel stands level with its confirm too', (tester) async {
    await tester.pumpWidget(
      host(
        AppModal(
          title: 'Compte',
          width: 480,
          actions: [
            TextButton(key: cancel, onPressed: () {}, child: const Text('Annuler')),
            PrimaryButton(key: confirm, label: 'Enregistrer', onPressed: () {}),
          ],
          child: const SizedBox(height: 40),
        ),
      ),
    );

    expectAligned(tester);
  });

  testWidgets('a confirm dialog outside the modal shell aligns as well', (tester) async {
    await tester.pumpWidget(
      host(
        AlertDialog(
          title: const Text('Archiver ?'),
          actions: [
            TextButton(key: cancel, onPressed: () {}, child: const Text('Annuler')),
            FilledButton(key: confirm, onPressed: () {}, child: const Text('Archiver')),
          ],
        ),
      ),
    );

    expectAligned(tester);
  });
}
