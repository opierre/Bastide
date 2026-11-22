import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/modal_parts.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

final dark = AppColors.dark;

void main() {
  group('ModalLoadingBody', () {
    testWidgets('draws a pulsing silhouette, never a spinner', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(width: 472, child: ModalLoadingBody()),
      );
      expect(find.byType(SkeletonPulse), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNWidgets(8));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ModalLoadError', () {
    for (final (locale, retry) in [
      (const Locale('fr'), 'Réessayer'),
      (const Locale('en'), 'Retry'),
    ]) {
      testWidgets('a warning banner with a secondary retry ($locale)', (
        tester,
      ) async {
        var retried = 0;
        await pumpHost(
          tester,
          SizedBox(
            width: 472,
            child: ModalLoadError(
              message: 'Impossible de préparer l’aperçu.',
              onRetry: () => retried++,
            ),
          ),
          locale: locale,
        );
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('modalLoadError')),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, dark.warning);
        await tester.tap(find.text(retry));
        expect(retried, 1);
      });
    }
  });

  group('ModalInPlaceAction', () {
    testWidgets('gives way to positive status text once done, and moves '
        'focus to the modal\'s initial focus', (tester) async {
      Widget modal(bool done) => AppModal(
        title: 'Restaurer cette sauvegarde ?',
        width: AppModalSizes.w500,
        kind: AppModalKind.destructive,
        actions: [
          const AppModalCancel(),
          AppButton(
            label: 'Remplacer mes données',
            variant: AppButtonVariant.destructive,
            onPressed: () {},
          ),
        ],
        child: ModalInPlaceAction(
          done: done,
          doneLabel: 'Sauvegarde enregistrée',
          action: AppButton(
            key: const Key('export'),
            label: 'Exporter d’abord',
            onPressed: () {},
          ),
        ),
      );

      await pumpHost(tester, modal(false));
      await tester.pump();
      expect(find.byKey(const Key('export')), findsOneWidget);
      expect(find.byKey(const Key('modalInPlaceDone')), findsNothing);

      await pumpHost(tester, modal(true));
      await tester.pump();
      expect(find.byKey(const Key('export')), findsNothing);
      final text = tester.widget<Text>(find.text('Sauvegarde enregistrée'));
      expect(text.style?.color, dark.positive);
      final focus = FocusManager.instance.primaryFocus!.context!;
      expect(focus.findAncestorWidgetOfExactType<AppModalCancel>(), isNotNull);
    });
  });

  group('ModalListRow', () {
    testWidgets('36 px, 48 px with two lines, no hairline', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(
          width: 472,
          child: ModalList(
            children: [
              ModalListRow(key: Key('one'), child: Text('Netflix')),
              ModalListRow(
                key: Key('two'),
                twoLines: true,
                child: Text('Basic-Fit'),
              ),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('one'))).height, 36);
      expect(tester.getSize(find.byKey(const Key('two'))).height, 48);
      expect(find.byType(Divider), findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('two'))).top -
            tester.getRect(find.byKey(const Key('one'))).bottom,
        2,
      );
    });

    testWidgets('a selectable row takes radius 4 and the hover ground under '
        'the pointer; the selected one accentSoft', (tester) async {
      await pumpHost(
        tester,
        SizedBox(
          width: 472,
          child: ModalList(
            children: [
              ModalListRow(
                key: const Key('row'),
                onTap: () {},
                child: const Text('Netflix'),
              ),
              ModalListRow(
                key: const Key('selected'),
                selected: true,
                onTap: () {},
                child: const Text('Basic-Fit'),
              ),
            ],
          ),
        ),
      );
      BoxDecoration deco(String key) =>
          firstDecorationUnder(tester, find.byKey(Key(key)));
      expect(
        tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byKey(const Key('row')),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration,
        isA<BoxDecoration>().having((d) => d.color, 'color', isNull),
      );
      expect(deco('selected').color, dark.accentSoft);
      expect(deco('selected').borderRadius, BorderRadius.circular(4));

      await hover(tester, find.byKey(const Key('row')));
      expect(deco('row').color, dark.hover);
      expect(deco('row').borderRadius, BorderRadius.circular(4));
    });
  });

  group('ModalFieldRow', () {
    testWidgets('a label on two lines moves both inputs down together; a '
        'helper under one does not push its neighbour', (tester) async {
      await pumpHost(
        tester,
        const SizedBox(
          width: 392,
          child: ModalFieldRow(
            start: ModalFieldCell(
              label: 'Valeur actuelle (facultative)',
              input: SizedBox(key: Key('a'), height: 32),
            ),
            end: ModalFieldCell(
              label: 'Versements déjà effectués à l’ouverture (facultatif)',
              input: SizedBox(key: Key('b'), height: 32),
              helper: 'Comptés comme un versement à l’ouverture.',
            ),
          ),
        ),
      );
      final a = tester.getRect(find.byKey(const Key('a')));
      final b = tester.getRect(find.byKey(const Key('b')));
      expect(a.top, b.top);
      expect(b.left - a.right, 16);
      final short = tester.getRect(find.text('Valeur actuelle (facultative)'));
      expect(a.top - short.bottom, 5);
    });
  });
}
