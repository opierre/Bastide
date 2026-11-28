import 'dart:ui' as ui;

import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/picture_crop_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import 'host.dart';

const _viewport = Key('pictureCropViewport');
const _value = Key('pictureCropZoomValue');

final dark = AppColors.dark;

void main() {
  late ui.Image image;
  Rect? saved;

  Future<void> open(
    WidgetTester tester, {
    bool round = false,
    Size viewport = const Size.square(AppModalSizes.cropSquare),
    double width = AppModalSizes.w420,
    Locale locale = const Locale('fr'),
    bool busy = false,
  }) async {
    image = (await tester.runAsync(
      () => createTestImage(width: 400, height: 200),
    ))!;
    saved = null;
    await pumpHost(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppModal<void>(
            context: context,
            builder: (_) => PictureCropModal(
              image: image,
              title: 'Recadrer le logo',
              lead: 'Faites glisser l’image pour cadrer le logo.',
              cancelLabel: 'Annuler',
              saveLabel: 'Utiliser ce logo',
              busy: busy,
              round: round,
              viewport: viewport,
              width: width,
              onSave: (_, crop) async {
                saved = crop;
                return true;
              },
            ),
          ),
          child: const Text('ouvrir'),
        ),
      ),
      locale: locale,
    );
    await tester.tap(find.text('ouvrir'));
    // A running upload spins forever, so it never settles.
    if (busy) {
      await tester.pump();
      await tester.pump(AppMotion.enter);
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the lead sits in the header; a 320 px square window, radius '
      '8, 1 px line, centred, with the zoom slider as wide under it', (
    tester,
  ) async {
    await open(tester);

    final title = tester.getRect(find.text('Recadrer le logo'));
    final lead = tester.getRect(
      find.text('Faites glisser l’image pour cadrer le logo.'),
    );
    expect(lead.top - title.bottom, 4);

    final window = tester.getRect(find.byKey(_viewport));
    expect(window.size, const Size.square(320));
    final frame = tester.getRect(find.byKey(const Key('appModalFrame')));
    expect(window.center.dx, frame.center.dx);
    final deco = decorationOf(tester, find.byKey(_viewport));
    expect(deco.borderRadius, BorderRadius.circular(8));
    expect(deco.border, Border.all(color: dark.line));

    final row = tester.getRect(
      find.ancestor(of: find.byKey(_value), matching: find.byType(Row)).first,
    );
    expect(row.width, 320);
    expect(row.left, window.left);
    expect(row.top - window.bottom, 14);
    expect(find.byIcon(LucideIcons300.zoomOut), findsOneWidget);
    expect(find.byIcon(LucideIcons300.zoomIn), findsOneWidget);
  });

  testWidgets('a banner crop takes the body\'s full width at its ratio', (
    tester,
  ) async {
    await open(
      tester,
      viewport: const Size(392, 392 * 19 / 44),
      width: AppModalSizes.w440,
    );
    final window = tester.getRect(find.byKey(_viewport));
    final frame = tester.getRect(find.byKey(const Key('appModalFrame')));
    expect(window.width, frame.width - 48);
  });

  for (final (locale, start, after) in [
    (const Locale('fr'), '1,0 ×', '1,1 ×'),
    (const Locale('en'), '1.0 ×', '1.1 ×'),
  ]) {
    testWidgets('+ zooms with the window focused, value printed ($locale)', (
      tester,
    ) async {
      await open(tester, locale: locale);
      expect(tester.widget<Text>(find.byKey(_value)).data, start);

      // A crop opens with focus on its window, the body's first control.
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(_value)).data, after);
    });
  }

  testWidgets('− never zooms below 1 ×; the slider reaches 5 ×', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadSubtract);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(_value)).data, '1,0 ×');

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(400, 0));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(_value)).data, '5,0 ×');
  });

  testWidgets('arrow keys move the picture under the window', (tester) async {
    await open(tester);
    await tester.tap(find.text('Utiliser ce logo'));
    await tester.pumpAndSettle();
    final centred = saved!;

    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.tap(find.text('Utiliser ce logo'));
    await tester.pumpAndSettle();
    expect(saved!.left, lessThan(centred.left));
  });

  testWidgets('the avatar crop draws the circle and veils the corners', (
    tester,
  ) async {
    await open(tester, round: true);
    expect(find.byKey(const Key('pictureCropGuide')), findsOneWidget);
  });

  testWidgets('a square logo crop draws no circle', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('pictureCropGuide')), findsNothing);
  });

  testWidgets('a running upload disables the window, the slider and the '
      'cancel', (tester) async {
    await open(tester, busy: true);
    expect(opacityAbove(tester, find.byKey(_viewport)), 0.45);
    expect(opacityAbove(tester, find.byKey(const Key('appModalCancel'))), 0.45);
  });
}
