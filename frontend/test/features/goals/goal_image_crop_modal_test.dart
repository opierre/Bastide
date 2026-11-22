import 'dart:ui' as ui;

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/goals/presentation/goal_image_crop_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(ui.Image image, {Locale locale = const Locale('fr')}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GoalImageCropModal(image: image, onSave: (_, _) async => true),
      ),
    ),
  );
}

void main() {
  testWidgets('the banner crop is 44:19 across the full body width', (
    tester,
  ) async {
    final image = await tester.runAsync(() => createTestImage(width: 40));
    await tester.pumpWidget(_wrap(image!));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('appModalFrame'))).width, 440);
    expect(find.text('Recadrer l’image'), findsOneWidget);
    expect(
      find.text('Faites glisser l’image pour cadrer la bannière.'),
      findsOneWidget,
    );
    final viewport = tester.getSize(
      find.byKey(const Key('pictureCropViewport')),
    );
    expect(viewport.width, 392);
    expect(viewport.width / viewport.height, closeTo(44 / 19, 1e-9));
    // A banner, not an avatar: no round guide over the window.
    expect(find.byKey(const Key('pictureCropGuide')), findsNothing);
    expect(find.byKey(const Key('pictureCropZoom')), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Utiliser cette image'), findsOneWidget);
  });

  testWidgets('English copy', (tester) async {
    final image = await tester.runAsync(() => createTestImage(width: 40));
    await tester.pumpWidget(_wrap(image!, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Crop the image'), findsOneWidget);
    expect(find.text('Use this image'), findsOneWidget);
  });
}
