import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'host.dart';

const _open = Key('open');
const _frame = Key('appModalFrame');
const _primary = Key('primary');
const _field = Key('field');

final dark = AppColors.dark;

/// Opens [modal] from a button through [showAppModal], as the app does.
Future<void> openModal(
  WidgetTester tester,
  Widget Function(BuildContext) modal, {
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) async {
  await pumpHost(
    tester,
    Builder(
      builder: (context) => TextButton(
        key: _open,
        onPressed: () => showAppModal<void>(context: context, builder: modal),
        child: const Text('ouvrir'),
      ),
    ),
    locale: locale,
    theme: theme,
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
}

Widget _primaryButton(BuildContext context, {VoidCallback? onPressed}) =>
    AppButton(
      key: _primary,
      label: 'Enregistrer',
      variant: AppButtonVariant.primary,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );

Widget _form(
  BuildContext context, {
  bool dirty = false,
  bool busy = false,
  String? saveError,
  VoidCallback? onSubmit,
}) => AppModal(
  title: 'Modifier le crédit',
  width: AppModalSizes.w480,
  dirty: dirty,
  busy: busy,
  saveError: saveError,
  onSubmit: onSubmit,
  actions: [const AppModalCancel(), _primaryButton(context)],
  child: Column(
    children: [
      TextField(key: _field),
      const SizedBox(height: AppSpacing.fieldGap),
      const TextField(key: Key('second')),
    ],
  ),
);

Widget _confirmation(
  BuildContext context, {
  AppModalKind kind = AppModalKind.confirmation,
}) => AppModal(
  title: 'Archiver ce compte ?',
  subtitle: const Text('Il n’apparaîtra plus dans votre liste de comptes.'),
  width: AppModalSizes.w420,
  kind: kind,
  actions: [const AppModalCancel(), _primaryButton(context)],
);

bool _focused(WidgetTester tester, Finder finder) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus?.context == null) return false;
  final element = tester.element(finder);
  var found = false;
  focus!.context!.visitAncestorElements((ancestor) {
    if (ancestor == element) found = true;
    return !found;
  });
  return found || focus.context == element;
}

void main() {
  group('frame', () {
    testWidgets('surface, radius 12, shadow, no border; no close button and '
        'no glyph before the title', (tester) async {
      await openModal(tester, _confirmation);

      final deco = decorationOf(tester, find.byKey(_frame));
      expect(deco.color, dark.surface);
      expect(deco.borderRadius, BorderRadius.circular(12));
      expect(deco.boxShadow, dark.shadow);
      expect(deco.border, isNull);
      expect(tester.getSize(find.byKey(_frame)).width, 420);
      expect(
        find.descendant(of: find.byKey(_frame), matching: find.byType(Icon)),
        findsNothing,
      );

      final title = tester.widget<Text>(find.text('Archiver ce compte ?'));
      expect(title.style?.fontSize, 16);
      expect(title.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('header padding 24, lead 4 px under the title, 13 '
        'textSecondary; a confirmation keeps its footer 24 px under the lead', (
      tester,
    ) async {
      await openModal(tester, _confirmation);

      final frame = tester.getRect(find.byKey(_frame));
      final title = tester.getRect(find.text('Archiver ce compte ?'));
      final lead = find.textContaining('Il n’apparaîtra plus');
      expect(title.topLeft - frame.topLeft, const Offset(24, 24));
      expect(tester.getRect(lead).top - title.bottom, 4);
      final leadStyle = DefaultTextStyle.of(tester.element(lead)).style;
      expect(leadStyle.fontSize, 13);
      expect(leadStyle.color, dark.textSecondary);

      expect(
        tester.getRect(find.byKey(_primary)).top - tester.getRect(lead).bottom,
        24,
      );
      expect(frame.bottom - tester.getRect(find.byKey(_primary)).bottom, 24);
    });

    testWidgets('a form body sits 14 px under the header; actions sit 8 px '
        'apart, right-aligned, a tertiary action alone on the left', (
      tester,
    ) async {
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Modifier la catégorie',
          width: AppModalSizes.w480,
          leadingAction: AppButton(
            key: const Key('delete'),
            label: 'Supprimer',
            variant: AppButtonVariant.ghost,
            onPressed: () {},
          ),
          actions: [const AppModalCancel(), _primaryButton(context)],
          child: const TextField(key: _field),
        ),
      );

      final frame = tester.getRect(find.byKey(_frame));
      expect(
        tester.getRect(find.byKey(_field)).top -
            tester.getRect(find.text('Modifier la catégorie')).bottom,
        14,
      );
      final cancel = tester.getRect(find.byKey(const Key('appModalCancel')));
      final primary = tester.getRect(find.byKey(_primary));
      expect(primary.left - cancel.right, 8);
      expect(frame.right - primary.right, 24);
      expect(
        tester.getRect(find.byKey(const Key('delete'))).left - frame.left,
        24,
      );
    });

    testWidgets('a long title wraps, balanced, and never widens the modal', (
      tester,
    ) async {
      const long =
          'Ajouter à « Adobe Creative Cloud, offre Photographie avec 20 Go '
          'de stockage en ligne »';
      await openModal(
        tester,
        (context) => AppModal(
          title: long,
          width: AppModalSizes.w560,
          actions: [const AppModalCancel()],
          child: const SizedBox(height: 40),
        ),
      );

      expect(tester.getSize(find.byKey(_frame)).width, 560);
      final title = tester.getRect(find.text(long));
      expect(title.height, greaterThan(30), reason: 'two lines');
      // Balanced: the box narrows below the 512 px available, so the
      // second line is not a short tail.
      expect(title.width, lessThan(512));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lead never ends on a lone word', (tester) async {
      // At 372 px, the greedy break leaves « perdu. » alone.
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Abandonner les modifications ?',
          subtitle: const Text(
            'Ce que vous avez saisi dans « Modifier le compte joint » sera '
            'perdu.',
          ),
          width: AppModalSizes.w420,
          actions: [const AppModalCancel()],
        ),
      );

      final lead = find.textContaining('Ce que vous avez saisi');
      final paragraph = tester.renderObject<RenderParagraph>(lead);
      final text = paragraph.text.toPlainText();
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      final lastTop = boxes.map((b) => b.top).reduce((a, b) => a > b ? a : b);
      final lastLine = boxes.where((b) => b.top == lastTop);
      final lastWidth = lastLine
          .map((b) => b.right - b.left)
          .reduce((a, b) => a + b);
      final perdu = (TextPainter(
        text: TextSpan(text: 'perdu.', style: paragraph.text.style),
        textDirection: TextDirection.ltr,
      )..layout()).width;
      expect(lastWidth, greaterThan(perdu + 1));
    });

    testWidgets('a short body draws no hairline', (tester) async {
      await openModal(tester, _form);

      expect(find.byKey(const Key('appModalHeaderHairline')), findsNothing);
      expect(find.byKey(const Key('appModalFooterHairline')), findsNothing);
    });

    testWidgets('a body that scrolls is the only part that does, set apart by '
        'hairlines 14 px from its content; the modal stops 24 px from the '
        'window', (tester) async {
      tester.view.physicalSize = const Size(1000, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Modifier le compte',
          width: AppModalSizes.w480,
          actions: [_primaryButton(context)],
          child: const SizedBox(key: Key('tall'), height: 1200),
        ),
      );

      final frame = tester.getRect(find.byKey(_frame));
      expect(frame.top, 24);
      expect(500 - frame.bottom, 24);

      final top = find.byKey(const Key('appModalHeaderHairline'));
      final bottom = find.byKey(const Key('appModalFooterHairline'));
      expect(top, findsOneWidget);
      expect(bottom, findsOneWidget);
      expect(tester.widget<Divider>(top).color, dark.line);
      expect(
        tester.getRect(find.byKey(const Key('tall'))).top -
            tester.getRect(top).bottom,
        14,
      );
      expect(
        tester.getRect(find.byKey(_primary)).top -
            tester.getRect(bottom).bottom,
        24,
      );
    });

    testWidgets('a failed save shows a negative banner at the top of the body '
        'and keeps the input', (tester) async {
      await openModal(
        tester,
        (context) => _form(
          context,
          saveError: 'La règle n’a pas été enregistrée. Rien n’a été modifié.',
        ),
      );

      final banner = find.byKey(const Key('appModalSaveError'));
      expect(banner, findsOneWidget);
      expect(
        tester.getRect(find.byKey(_field)).top - tester.getRect(banner).bottom,
        14,
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: banner, matching: find.byType(Icon)),
      );
      expect(icon.color, dark.negative);
    });

    testWidgets('a running save disables the fields and the other actions', (
      tester,
    ) async {
      await openModal(tester, (context) => _form(context, busy: true));

      expect(opacityAbove(tester, find.byKey(_field)), 0.45);
      expect(
        opacityAbove(tester, find.byKey(const Key('appModalCancel'))),
        0.45,
      );
      await tester.tap(find.byKey(_field), warnIfMissed: false);
      await tester.pump();
      expect(_focused(tester, find.byKey(_field)), isFalse);
    });

    testWidgets('the light theme draws the same frame in its own tokens', (
      tester,
    ) async {
      await openModal(tester, _confirmation, theme: AppTheme.light);

      final deco = decorationOf(tester, find.byKey(_frame));
      expect(deco.color, AppColors.light.surface);
      expect(deco.boxShadow, AppColors.light.shadow);
    });
  });

  group('closing', () {
    testWidgets('Escape and the scrim act as the secondary action on a '
        'confirmation', (tester) async {
      await openModal(tester, _confirmation);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);

      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('a click on the frame itself closes nothing', (tester) async {
      await openModal(tester, _confirmation);
      await tester.tap(find.text('Archiver ce compte ?'));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('an untouched form closes on Escape and on the scrim', (
      tester,
    ) async {
      await openModal(tester, _form);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('a form with unsaved input ignores the scrim', (tester) async {
      await openModal(tester, (context) => _form(context, dirty: true));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
      expect(find.byKey(const Key('appModalDiscard')), findsNothing);
    });

    testWidgets('Escape on a form with unsaved input asks « Abandonner les '
        'modifications ? »; its own Escape returns to the form', (
      tester,
    ) async {
      await openModal(tester, (context) => _form(context, dirty: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final discard = find.byKey(const Key('appModalDiscard'));
      expect(discard, findsOneWidget);
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(
        find.text(
          'Ce que vous avez saisi dans « Modifier le crédit » sera '
          'perdu.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.descendant(of: discard, matching: find.byKey(_frame)))
            .width,
        420,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(discard, findsNothing);
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('« Annuler » on a form with unsaved input asks first; '
        '« Abandonner » closes both', (tester) async {
      await openModal(tester, (context) => _form(context, dirty: true));
      await tester.tap(find.byKey(const Key('appModalCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('appModalDiscardConfirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('« Continuer la saisie » keeps the form', (tester) async {
      await openModal(tester, (context) => _form(context, dirty: true));
      await tester.tap(find.byKey(const Key('appModalCancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appModalDiscardContinue')));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
      expect(find.byKey(const Key('appModalDiscard')), findsNothing);
    });

    testWidgets('nothing closes while a save runs', (tester) async {
      await openModal(tester, (context) => _form(context, busy: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('a single way out ignores Escape and the scrim', (
      tester,
    ) async {
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Nouveau code de récupération',
          width: AppModalSizes.w480,
          kind: AppModalKind.singleWayOut,
          actions: [_primaryButton(context)],
          child: AppButton(
            key: const Key('copy'),
            label: 'Copier',
            onPressed: () {},
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('a form opens on its first field', (tester) async {
      await openModal(tester, _form);
      expect(_focused(tester, find.byKey(_field)), isTrue);
    });

    testWidgets('a destructive confirmation opens on « Annuler »', (
      tester,
    ) async {
      await openModal(
        tester,
        (context) => _confirmation(context, kind: AppModalKind.destructive),
      );
      expect(_focused(tester, find.byKey(const Key('appModalCancel'))), isTrue);
    });

    testWidgets('a destructive confirmation opens on « Annuler », not on the '
        'ghost action on its left', (tester) async {
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Restaurer cette sauvegarde ?',
          width: AppModalSizes.w500,
          kind: AppModalKind.destructive,
          leadingAction: AppButton(
            key: const Key('exportFirst'),
            label: 'Exporter d’abord',
            variant: AppButtonVariant.ghost,
            onPressed: () {},
          ),
          actions: [const AppModalCancel(), _primaryButton(context)],
        ),
      );
      expect(_focused(tester, find.byKey(const Key('appModalCancel'))), isTrue);
    });

    testWidgets('a reversible confirmation opens on its primary action', (
      tester,
    ) async {
      await openModal(tester, _confirmation);
      expect(_focused(tester, find.byKey(_primary)), isTrue);
    });

    testWidgets('a single way out opens on the copy action, so Enter cannot '
        'dismiss it', (tester) async {
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Nouveau code de récupération',
          width: AppModalSizes.w480,
          kind: AppModalKind.singleWayOut,
          actions: [_primaryButton(context)],
          child: AppButton(
            key: const Key('copy'),
            label: 'Copier',
            onPressed: () {},
          ),
        ),
      );
      expect(_focused(tester, find.byKey(const Key('copy'))), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('Tab stays inside the modal', (tester) async {
      await openModal(tester, _form);
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(tester, find.byKey(_frame)), isTrue);
      }
    });

    testWidgets('Enter submits from a single-line field', (tester) async {
      var submitted = 0;
      await openModal(
        tester,
        (context) => _form(context, onSubmit: () => submitted++),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, 1);
    });

    testWidgets('Enter does not submit while a save runs', (tester) async {
      var submitted = 0;
      await openModal(
        tester,
        (context) => AppModal(
          title: 'Renommer le scénario',
          width: AppModalSizes.w420,
          busy: true,
          onSubmit: () => submitted++,
          actions: [_primaryButton(context)],
          child: const TextField(key: _field, autofocus: true),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, 0);
    });

    testWidgets('focus returns to the opener on close', (tester) async {
      await pumpHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            key: _open,
            onPressed: () =>
                showAppModal<void>(context: context, builder: _confirmation),
            child: const Text('ouvrir'),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(tester, find.byKey(_open)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsOneWidget);
      expect(_focused(tester, find.byKey(_open)), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_focused(tester, find.byKey(_open)), isTrue);
    });

    testWidgets('the modal is named by its title and described by its lead', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openModal(tester, _confirmation);
      expect(find.bySemanticsLabel('Archiver ce compte ?'), findsWidgets);
      SemanticsNode? named;
      bool visit(SemanticsNode node) {
        if (node.getSemanticsData().flagsCollection.namesRoute) {
          named = node;
          return false;
        }
        node.visitChildren(visit);
        return named == null;
      }

      var root = tester.getSemantics(find.byKey(_frame));
      while (root.parent != null) {
        root = root.parent!;
      }
      root.visitChildren(visit);
      final node = named!;
      expect(node.label, 'Archiver ce compte ?');
      expect(node.hint, 'Il n’apparaîtra plus dans votre liste de comptes.');
      semantics.dispose();
    });
  });

  group('acknowledgement', () {
    Widget ack(BuildContext context) => const AppModal(
      title: 'Pack refusé',
      width: AppModalSizes.w480,
      kind: AppModalKind.acknowledgement,
      actions: [AppModalClose()],
      child: Text('Ce fichier n’est pas un pack de règles.'),
    );

    testWidgets('one primary « Fermer », focused; Escape closes it', (
      tester,
    ) async {
      await openModal(tester, ack);
      final close = find.byKey(const Key('appModalClose'));
      expect(find.text('Fermer'), findsOneWidget);
      expect(_focused(tester, close), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('« Close » in English closes it', (tester) async {
      await openModal(tester, ack, locale: const Locale('en'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(_frame), findsNothing);
    });

    testWidgets('a list editor footer has a secondary « Fermer »', (
      tester,
    ) async {
      await openModal(
        tester,
        (context) => const AppModal(
          title: 'Historique déclaré',
          width: AppModalSizes.w560,
          kind: AppModalKind.listEditor,
          actions: [AppModalClose(primary: false)],
          child: TextField(key: _field),
        ),
      );
      final button = tester.widget<AppButton>(
        find.byKey(const Key('appModalClose')),
      );
      expect(button.variant, AppButtonVariant.secondary);
      expect(_focused(tester, find.byKey(_field)), isTrue);
    });
  });

  group('copy', () {
    for (final (locale, title, cancel) in [
      (const Locale('fr'), 'Abandonner les modifications ?', 'Annuler'),
      (const Locale('en'), 'Discard your changes?', 'Cancel'),
    ]) {
      testWidgets('the cancel and discard copy follow the locale ($locale)', (
        tester,
      ) async {
        await openModal(
          tester,
          (context) => _form(context, dirty: true),
          locale: locale,
        );
        expect(find.text(cancel), findsOneWidget);
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      });
    }
  });
}
