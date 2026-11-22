import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/networth/application/networth_controller.dart';
import 'package:bastide/features/networth/presentation/networth_screen.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/features/properties/presentation/property_form_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
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
  FakeNetworthController? networth,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      networthControllerProvider.overrideWith(
        () => networth ?? FakeNetworthController(),
      ),
      propertiesControllerProvider.overrideWith(() => properties),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the table lists each property with its share and held value', (
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

    for (final header in const [
      'Bien',
      'Nature',
      'Quote-part',
      'Valeur détenue',
    ]) {
      expect(find.text(header), findsOneWidget);
    }
    expect(_text(tester, 'propertiesCount'), '2');
    expect(find.byKey(const Key('propertyRow-p1')), findsOneWidget);
    expect(_text(tester, 'propertyHeldValue-p2'), _money(7250000));
    expect(_text(tester, 'propertyKind-p2'), 'Locatif');
    // French sets a no-break space before « % »: read it from the formatter.
    expect(
      _text(tester, 'propertyOwnership-p2'),
      formatOwnershipShare(5000, 'fr'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('propertyKind-p2')))
          .style!
          .color,
      AppColors.dark.textSecondary,
    );
    expect(find.byKey(const Key('propertiesArchivedToggle')), findsNothing);
  });

  testWidgets('a row with an address takes two lines', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(
          initialProperties: [
            testProperty(address: '3 rue des Glycines, 69003 Lyon'),
            testStudio(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _text(tester, 'propertyAddress-p1'),
      '3 rue des Glycines, 69003 Lyon',
    );
    expect(find.byKey(const Key('propertyAddress-p2')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('propertyRow-p1'))).height,
      AppSizes.tableRowTwoLines,
    );
    expect(
      tester.getSize(find.byKey(const Key('propertyRow-p2'))).height,
      AppSizes.tableRow,
    );
  });

  testWidgets('the same table in English', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(initialProperties: [testStudio()]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Held value'), findsOneWidget);
    expect(_text(tester, 'propertyOwnership-p2'), '50%');
    expect(_text(tester, 'propertyKind-p2'), 'Rental');
  });

  testWidgets('a row opens the property form on it', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(FakePropertiesController(initialProperties: [testStudio()])),
    );
    await tester.pumpAndSettle();

    await _tap(tester, 'propertyRow-p2');

    expect(find.text('Modifier le bien'), findsOneWidget);
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

    await _tap(tester, 'propertyMenu-p2');
    await tester.tap(find.byKey(const Key('propertyMenu-archive')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, ['p2']);
    expect(find.byKey(const Key('propertyRow-p2')), findsNothing);
    expect(_text(tester, 'propertiesCount'), '1');
    expect(find.text('1 bien archivé'), findsOneWidget);

    await _tap(tester, 'propertiesArchivedToggle');
    expect(find.byKey(const Key('propertyRow-p2')), findsOneWidget);

    await _tap(tester, 'propertyMenu-p2');
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

    await _tap(tester, 'propertyMenu-p2');
    await tester.tap(find.byKey(const Key('propertyMenu-revalue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('propertyRevalueSubmit')), findsOneWidget);
    expect(
      _text(tester, 'propertyRevalueSubtitle'),
      'Studio Villeurbanne : ${_money(14500000)} estimés le 5 mars 2026. '
      'La nouvelle estimation remplace celle-ci.',
    );
  });

  testWidgets('no property: a note and a link to declare one', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(),
        networth: FakeNetworthController(summary: testNoPropertySummary()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('propertiesEmptyNote')), findsOneWidget);
    expect(
      find.text(
        'Aucun bien déclaré : l’actif ne compte que vos comptes et vos '
        'placements.',
      ),
      findsOneWidget,
    );
    expect(find.text('Bien'), findsNothing);

    await _tap(tester, 'propertiesEmptyAdd');
    expect(find.byKey(const Key('propertyFormSubmit')), findsOneWidget);
  });

  testWidgets('renders in the light theme with its own tokens', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePropertiesController(initialProperties: [testStudio()]),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('propertyKind-p2')))
          .style!
          .color,
      AppColors.light.textSecondary,
    );
  });
}
