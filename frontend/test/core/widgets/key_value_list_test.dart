import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/key_value_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

final dark = AppColors.dark;

void main() {
  group('KeyValueComparison', () {
    Future<void> pump(WidgetTester tester) => pumpHost(
      tester,
      const SizedBox(
        width: 452,
        child: KeyValueComparison(
          headers: ['Sauvegarde', 'Actuel'],
          rows: [
            KeyValues('Comptes', ['4', '5'], key: Key('accounts')),
            KeyValues('Transactions', ['1 284', '1 342']),
          ],
        ),
      ),
    );

    testWidgets('heads each source in textTertiary, right-aligned', (
      tester,
    ) async {
      await pump(tester);
      final header = tester.widget<Text>(find.text('Sauvegarde'));
      expect(header.style?.color, dark.textTertiary);
      expect(header.textAlign, TextAlign.end);
      expect(
        tester.getTopRight(find.text('Actuel')).dx,
        moreOrLessEquals(tester.getTopRight(find.text('1 342')).dx),
      );
    });

    testWidgets('sets values in text, a difference not coloured', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.widget<Text>(find.text('4')).style?.color, dark.text);
      expect(tester.widget<Text>(find.text('5')).style?.color, dark.text);
      expect(
        tester.widget<Text>(find.text('Comptes')).style?.color,
        dark.textSecondary,
      );
      expect(find.byKey(const Key('accounts')), findsOneWidget);
    });

    testWidgets('keeps the value columns 24 px apart and rows 8 px apart', (
      tester,
    ) async {
      await pump(tester);
      final backupRight = tester.getTopRight(find.text('1 284')).dx;
      final currentLeft = tester.getTopLeft(find.text('1 342')).dx;
      expect(currentLeft - backupRight, greaterThanOrEqualTo(AppSpacing.lg));
      final first = tester.getBottomLeft(find.text('Comptes')).dy;
      final second = tester.getTopLeft(find.text('Transactions')).dy;
      expect(second - first, moreOrLessEquals(AppSpacing.sm, epsilon: 1));
    });
  });
}
