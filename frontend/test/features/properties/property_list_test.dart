import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/networth/application/networth_controller.dart';
import 'package:finstride/features/networth/presentation/networth_screen.dart';
import 'package:finstride/features/properties/application/properties_controller.dart';
import 'package:finstride/features/properties/presentation/property_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/networth_fixtures.dart';
import '../../support/properties_fixtures.dart';

String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap(
  FakePropertiesController properties, {
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      networthControllerProvider.overrideWith(FakeNetworthController.new),
      propertiesControllerProvider.overrideWith(() => properties),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: NetworthScreen()),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

Future<void> _openProperties(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('networthPropertiesSegment')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cards show the held value, its date and the share below 100 %', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(
          initialProperties: [testProperty(), testStudio()],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openProperties(tester);

    final held = tester.widget<AmountText>(
      find.byKey(const Key('propertyHeldValue-p2')),
    );
    expect(held.amountMinor, 7250000);
    expect(held.colorize, isFalse);
    expect(
      _text(tester, 'propertyCaption-p2'),
      'part détenue · sur ${_money(14500000)} estimés le 05/03/2026',
    );
    // French sets a no-break space before « % »: read it from the formatter.
    expect(
      _text(tester, 'propertyOwnership-p2'),
      formatOwnershipShare(5000, 'fr'),
    );
    expect(formatOwnershipShare(5000, 'fr'), '50 %');
    expect(
      _text(tester, 'propertySinceAcquisition-p2'),
      '${_money(650000)} au-dessus (part)',
    );

    expect(
      _text(tester, 'propertyCaption-p1'),
      'valeur déclarée · estimée le 12/01/2026',
    );
    expect(
      _text(tester, 'propertyOwnership-p1'),
      formatOwnershipShare(10000, 'fr'),
    );
    expect(
      _text(tester, 'propertyAcquisition-p1'),
      '${_money(38500000)} · 01/09/2023',
    );
    expect(
      _text(tester, 'propertySinceAcquisition-p1'),
      '${_money(3500000)} au-dessus',
    );
    expect(find.byKey(const Key('propertyNewTile')), findsOneWidget);
  });

  testWidgets('the same cards in English', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(initialProperties: [testStudio()]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await _openProperties(tester);

    expect(
      _text(tester, 'propertyCaption-p2'),
      'held share · of ${_money(14500000, locale: 'en')} valued on 3/5/2026',
    );
    expect(_text(tester, 'propertyOwnership-p2'), '50%');
  });

  testWidgets('archiving from the menu moves the property behind the link', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController(
      initialProperties: [testProperty(), testStudio()],
    );
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();
    await _openProperties(tester);

    expect(find.text('Afficher les biens archivés (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('propertyMenu-p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('propertyMenu-archive')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, ['p2']);
    expect(find.byKey(const Key('propertyCard-p2')), findsNothing);
    expect(find.text('Biens (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('propertiesArchivedToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('propertyCard-p2')), findsOneWidget);
    expect(find.text('Masquer les biens archivés (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('propertyMenu-p2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('propertyMenu-archive')), findsNothing);
    await tester.tap(find.byKey(const Key('propertyMenu-unarchive')));
    await tester.pumpAndSettle();
    expect(controller.unarchiveCalls, ['p2']);
  });

  testWidgets('« Nouvelle estimation » opens on the property it revalues', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(FakePropertiesController(initialProperties: [testStudio()])),
    );
    await tester.pumpAndSettle();
    await _openProperties(tester);

    await tester.tap(find.byKey(const Key('propertyMenu-p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('propertyMenu-revalue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('propertyRevalueSubmit')), findsOneWidget);
    expect(
      _text(tester, 'propertyRevalueSubtitle'),
      startsWith(
        'Studio Villeurbanne : ${_money(14500000)} estimés le 05/03/2026',
      ),
    );
  });
}
