import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/features/properties/application/properties_controller.dart';
import 'package:bastide/features/properties/domain/property.dart';
import 'package:bastide/features/properties/presentation/property_form_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/properties_fixtures.dart';

Widget _wrap({
  required FakePropertiesController controller,
  required Widget modal,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [propertiesControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: modal),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _dateInput(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

/// The frame ③ worked example: the studio held at 50 %.
Future<void> _fillStudio(WidgetTester tester, {String ownership = '50'}) async {
  await tester.enterText(
    find.byKey(const Key('propertyFormLabel')),
    'Studio Villeurbanne',
  );
  await tester.enterText(find.byKey(const Key('propertyFormValue')), '145000');
  await tester.enterText(_dateInput('propertyFormValuedOn'), '05/03/2026');
  await tester.enterText(
    find.byKey(const Key('propertyFormOwnership')),
    ownership,
  );
  await tester.pump();
}

void main() {
  group('ownership percent', () {
    test('reads to basis points on the digits', () {
      expect(parseOwnershipBps('50'), 5000);
      expect(parseOwnershipBps('33,33'), 3333);
      expect(parseOwnershipBps('12.5'), 1250);
      expect(parseOwnershipBps('100'), 10000);
      expect(parseOwnershipBps('0,01'), 1);
    });

    test('refuses a share the API would refuse', () {
      expect(parseOwnershipBps('0'), isNull);
      expect(parseOwnershipBps('100,01'), isNull);
      expect(parseOwnershipBps('150'), isNull);
      expect(parseOwnershipBps('1,234'), isNull);
      expect(parseOwnershipBps('abc'), isNull);
    });

    test('prefills in the locale spelling', () {
      expect(formatOwnershipInput(10000, 'fr'), '100');
      expect(formatOwnershipInput(3333, 'fr'), '33,33');
      expect(formatOwnershipInput(3350, 'en'), '33.50');
    });
  });

  testWidgets('an empty submit explains each missing field and saves nothing', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        modal: const PropertyFormModal(currency: 'EUR'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('propertyFormOwnership')), '0');
    await tester.tap(find.byKey(const Key('propertyFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Donnez un nom à ce bien.'), findsOneWidget);
    expect(find.text('Saisissez un montant supérieur à zéro.'), findsOneWidget);
    expect(find.text('Date invalide (JJ/MM/AAAA).'), findsOneWidget);
    expect(
      find.text('Indiquez une quote-part entre 0,01 et 100 %.'),
      findsOneWidget,
    );
    expect(controller.createCalls, isEmpty);
  });

  testWidgets(
    'the ownership label carries the held share live, and saves in bps',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakePropertiesController();
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          modal: const PropertyFormModal(currency: 'EUR'),
        ),
      );
      await tester.pumpAndSettle();

      // Opens at 100 %: no share to state until there is a value.
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('propertyFormOwnership')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '100',
      );
      expect(find.byKey(const Key('propertyFormOwnershipShare')), findsNothing);

      await _fillStudio(tester);
      final share = formatAmount(
        amountMinor: 7250000,
        currency: 'EUR',
        locale: 'fr',
      );
      expect(_text(tester, 'propertyFormOwnershipShare'), 'part : $share');

      await tester.tap(find.byKey(const Key('propertyFormKind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Locatif').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('propertyFormSubmit')));
      await tester.pumpAndSettle();

      final draft = controller.createCalls.single;
      expect(draft.label, 'Studio Villeurbanne');
      expect(draft.kind, PropertyKind.rental);
      expect(draft.marketValueMinor, 14500000);
      expect(draft.valuedOn, DateTime(2026, 3, 5));
      expect(draft.ownershipBps, 5000);
      expect(draft.acquisitionPriceMinor, isNull);
      expect(draft.acquiredOn, isNull);
    },
  );

  testWidgets('a decimal share converts on the digits', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        modal: const PropertyFormModal(currency: 'EUR'),
      ),
    );
    await tester.pumpAndSettle();

    await _fillStudio(tester, ownership: '33,33');
    await tester.enterText(
      find.byKey(const Key('propertyFormAcquisitionPrice')),
      '132000',
    );
    await tester.enterText(_dateInput('propertyFormAcquiredOn'), '14/06/2021');
    await tester.tap(find.byKey(const Key('propertyFormSubmit')));
    await tester.pumpAndSettle();

    final draft = controller.createCalls.single;
    expect(draft.ownershipBps, 3333);
    expect(draft.acquisitionPriceMinor, 13200000);
    expect(draft.acquiredOn, DateTime(2021, 6, 14));
  });

  testWidgets('editing prefills every declared input', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        modal: PropertyFormModal(currency: 'EUR', initial: testStudio()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier le bien'), findsOneWidget);
    expect(
      _text(tester, 'propertyFormOwnershipShare'),
      'part : ${formatAmount(amountMinor: 7250000, currency: 'EUR', locale: 'fr')}',
    );

    await tester.tap(find.byKey(const Key('propertyFormSubmit')));
    await tester.pumpAndSettle();

    final (id, draft) = controller.updateCalls.single;
    expect(id, 'p2');
    expect(draft.ownershipBps, 5000);
    expect(draft.marketValueMinor, 14500000);
    expect(draft.acquisitionPriceMinor, 13200000);
  });

  testWidgets('a valuation in the future is explained under its date', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController()
      ..errorOnSave = const ApiFailure(
        code: 'PROPERTY_VALUATION_IN_FUTURE',
        message: 'future',
      );
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        modal: const PropertyFormModal(currency: 'EUR'),
      ),
    );
    await tester.pumpAndSettle();

    await _fillStudio(tester);
    await tester.tap(find.byKey(const Key('propertyFormSubmit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Une date d\'estimation ne peut pas être dans le futur.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('propertyFormError')), findsNothing);
  });

  testWidgets('a new valuation sends the value with its date', (tester) async {
    _useDesktopSurface(tester);
    final controller = FakePropertiesController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        locale: const Locale('en'),
        modal: PropertyRevalueModal(property: testStudio()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New valuation'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('propertyRevalueValue')),
      '150000',
    );
    await tester.enterText(_dateInput('propertyRevalueValuedOn'), '5/2/2026');
    await tester.tap(find.byKey(const Key('propertyRevalueSubmit')));
    await tester.pumpAndSettle();

    expect(controller.revalueCalls.single, (
      'p2',
      15000000,
      DateTime(2026, 5, 2),
    ));
  });
}
