import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_checkbox.dart';
import 'package:bastide/core/widgets/note_line.dart';
import 'package:bastide/features/simulator/application/simulator_controller.dart';
import 'package:bastide/features/simulator/data/simulations_repository.dart';
import 'package:bastide/features/simulator/domain/simulation.dart';
import 'package:bastide/features/simulator/domain/simulation_result.dart';
import 'package:bastide/features/simulator/presentation/simulator_labels.dart';
import 'package:bastide/features/simulator/presentation/simulator_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/simulator_fixtures.dart';

class MockSimulationsRepository extends Mock implements SimulationsRepository {}

Widget _wrap(
  MockSimulationsRepository repository, {
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [simulationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SimulatorTopBarActions(),
            Expanded(child: SimulatorScreen()),
          ],
        ),
      ),
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

Future<void> _load(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Lets the debounce elapse, the compute land, and any menu or dialog settle.
/// Never `pumpAndSettle`: the focused field's cursor blinks forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(
    SimulatorController.debounce + const Duration(milliseconds: 50),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _typeFrame(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('simulatorPrice')), '320000');
  await tester.enterText(
    find.byKey(const Key('simulatorDownPayment')),
    '40000',
  );
  await tester.enterText(find.byKey(const Key('simulatorFees')), '4500');
  await tester.enterText(find.byKey(const Key('simulatorRate')), '3,25');
  await tester.enterText(find.byKey(const Key('simulatorInsurance')), '32');
  await _settle(tester);
}

/// Scrolls a scenario row into the inputs pane's viewport, then taps it: at
/// 900 px the pane shows only its first rows, as a user would find it.
Future<void> _tapRow(
  WidgetTester tester,
  String id, {
  bool warnIfMissed = true,
}) async {
  final row = find.byKey(Key('scenarioRow-$id'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row, warnIfMissed: warnIfMissed);
}

final _threeScenarios = [
  testScenario(),
  testScenario(id: 's2', label: 'Lyon 7e, 350\u00A0k€'),
  testScenario(id: 's3', label: 'Lyon 8e, 290\u00A0k€'),
];

void main() {
  late MockSimulationsRepository repository;

  setUpAll(() => registerFallbackValue(testTerms));

  setUp(() {
    repository = MockSimulationsRepository();
    when(() => repository.household()).thenAnswer((_) async => testHousehold());
    when(() => repository.list()).thenAnswer((_) async => _threeScenarios);
    when(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    ).thenAnswer((invocation) async {
      final terms = invocation.positionalArguments.first as SimulationTerms;
      // No price, no cost-over-price: the API's null, not a zero.
      return terms.propertyPriceMinor == null
          ? testResult(costOverPriceBps: null)
          : testResult();
    });
  });

  testWidgets('with nothing saved the block is a note with no compare '
      'control', (tester) async {
    _useDesktopSurface(tester);
    when(() => repository.list()).thenAnswer((_) async => []);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    expect(find.byKey(const Key('scenariosEmpty')), findsOneWidget);
    expect(find.text('Aucun scénario enregistré.'), findsOneWidget);
    expect(find.byKey(const Key('scenarioRow-live')), findsNothing);
    expect(find.byKey(const Key('scenarioCompareButton')), findsNothing);
  });

  testWidgets('saving names the inputs on the place, price pattern, even '
      'over the reference', (tester) async {
    _useDesktopSurface(tester);
    when(() => repository.list()).thenAnswer((_) async => []);
    when(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    ).thenAnswer((_) async => testOverLimitResult());
    when(() => repository.create(any(), any())).thenAnswer(
      (invocation) async => testScenario(
        id: 's9',
        label: invocation.positionalArguments.first as String,
        terms: testTerms,
      ),
    );
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    final saveButton = find.byKey(const Key('simulatorSaveButton'));
    expect(tester.widget<AppButton>(saveButton).onPressed, isNull);

    await _typeFrame(tester);
    expect(tester.widget<AppButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await _settle(tester);

    final nameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('saveScenarioName')),
        matching: find.byType(EditableText),
      ),
    );
    expect(nameField.controller.text, ', 320\u00A0k€');
    expect(nameField.controller.selection.baseOffset, 0);

    await tester.enterText(
      find.byKey(const Key('saveScenarioName')),
      'Lyon 3e, 320\u00A0k€',
    );
    await tester.tap(find.byKey(const Key('saveScenarioSubmit')));
    await _settle(tester);

    verify(
      () => repository.create('Lyon 3e, 320\u00A0k€', testTerms),
    ).called(1);
    expect(find.byKey(const Key('saveScenarioName')), findsNothing);
    expect(_text(tester, 'scenarioName-s9'), 'Lyon 3e, 320\u00A0k€');
  });

  testWidgets('the live row comes first, its sub-line led by « en cours »', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    final live = tester.getTopLeft(find.byKey(const Key('scenarioRow-live')));
    final saved = tester.getTopLeft(find.byKey(const Key('scenarioRow-s1')));
    expect(live.dy, lessThan(saved.dy));
    expect(_text(tester, 'scenarioName-live'), '320\u00A0k€');
    expect(
      _text(tester, 'scenarioSub-live'),
      'en cours · ${formatRate(325, 'fr')} · 25 ans',
    );
    expect(
      _text(tester, 'scenarioSub-s1'),
      '${formatRate(325, 'fr')} · 25 ans',
    );
    expect(
      _text(tester, 'scenarioInstalment-s1'),
      formatAmount(amountMinor: 141841, currency: 'EUR', locale: 'fr'),
    );
  });

  testWidgets('rename opens the name dialog on the current name and patches '
      'it', (tester) async {
    _useDesktopSurface(tester);
    when(() => repository.rename(any(), any())).thenAnswer(
      (invocation) async =>
          testScenario(label: invocation.positionalArguments[1] as String),
    );
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    await tester.tap(find.byKey(const Key('scenarioMenu-s1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('scenarioRename-s1')));
    await _settle(tester);

    expect(find.text('Renommer le scénario'), findsOneWidget);
    final nameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('saveScenarioName')),
        matching: find.byType(EditableText),
      ),
    );
    expect(nameField.controller.text, testScenario().label);

    await tester.enterText(
      find.byKey(const Key('saveScenarioName')),
      'Villeurbanne, 270\u00A0k€',
    );
    await tester.tap(find.byKey(const Key('saveScenarioSubmit')));
    await _settle(tester);

    verify(
      () => repository.rename('s1', 'Villeurbanne, 270\u00A0k€'),
    ).called(1);
    expect(_text(tester, 'scenarioName-s1'), 'Villeurbanne, 270\u00A0k€');
  });

  testWidgets('delete removes a saved row at once, with no confirmation', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    when(() => repository.delete(any())).thenAnswer((_) async {});
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    await tester.tap(find.byKey(const Key('scenarioMenu-s1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('scenarioDelete-s1')));
    await _settle(tester);

    verify(() => repository.delete('s1')).called(1);
    expect(find.byKey(const Key('scenarioRow-s1')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('compare takes three with the live row, then disables the rest '
      'and says how to free a slot', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    AppButton compare() => tester.widget<AppButton>(
      find.byKey(const Key('scenarioCompareButton')),
    );

    expect(compare().onPressed, isNull);
    await _tapRow(tester, 'live');
    await _settle(tester);
    expect(compare().onPressed, isNotNull);

    await _tapRow(tester, 's1');
    await _tapRow(tester, 's2');
    await _settle(tester);

    expect(find.text('Comparer (3/3)'), findsOneWidget);
    expect(compare().onPressed, isNotNull);
    await tester.ensureVisible(find.byKey(const Key('scenarioRow-s3')));
    await tester.pump();
    expect(
      tester
          .widget<AppCheckbox>(find.byKey(const Key('scenarioCheck-s3')))
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<NoteLine>(find.byKey(const Key('scenarioNote'))).text,
      'Trois scénarios au plus. Décochez-en un pour ajouter Lyon 8e, 290\u00A0k€.',
    );

    // A fourth check is ignored rather than swapped in.
    await _tapRow(tester, 's3', warnIfMissed: false);
    await _settle(tester);
    expect(find.text('Comparer (3/3)'), findsOneWidget);
  });

  testWidgets('the comparison reads the same rows across, with a dash where a '
      'figure does not apply', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    // A live simulation with no price: no cost-over-price to show.
    await tester.enterText(
      find.byKey(const Key('simulatorPrincipal')),
      '250000',
    );
    await tester.enterText(find.byKey(const Key('simulatorRate')), '3,25');
    await _settle(tester);

    for (final id in ['live', 's1', 's2']) {
      await _tapRow(tester, id);
    }
    await _settle(tester);
    await tester.tap(find.byKey(const Key('scenarioCompareButton')));
    await _settle(tester);

    expect(find.byKey(const Key('comparison')), findsOneWidget);
    expect(find.byKey(const Key('hcsfReading')), findsNothing);
    expect(_text(tester, 'compareTitle'), 'Comparaison de 3 scénarios');
    expect(_text(tester, 'compareHeader-live'), 'Simulation en cours');
    expect(_text(tester, 'compareLiveMarker'), 'en cours');
    expect(_text(tester, 'compareHeader-s1'), 'Villeurbanne, 265 k€');
    expect(_text(tester, 'compare-term-s1'), '25 ans');

    expect(_text(tester, 'compare-price-live'), '—');
    expect(_text(tester, 'compare-costShare-live'), '—');
    expect(_text(tester, 'compare-costShare-s1'), startsWith('45,5'));
    expect(_text(tester, 'compare-insurance-s1'), '—');
    expect(
      _text(tester, 'compare-instalment-s2'),
      formatAmount(amountMinor: 141841, currency: 'EUR', locale: 'fr'),
    );
    expect(_text(tester, 'compare-ratio-s1'), startsWith('30,8'));
    expect(_text(tester, 'compare-taeg-s1'), startsWith('3,67'));
    expect(
      find.descendant(
        of: find.byKey(const Key('compareFoot')),
        matching: find.textContaining('qui n’engage aucun prêteur'),
      ),
      findsOneWidget,
    );
    // Every column carries every row.
    for (final id in ['live', 's1', 's2']) {
      expect(find.byKey(Key('compare-ratioWithExisting-$id')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('compareClose')));
    await _settle(tester);
    expect(find.byKey(const Key('comparison')), findsNothing);
    expect(find.byKey(const Key('hcsfReading')), findsOneWidget);
  });

  testWidgets('prints the scenarios and the comparison in English', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    when(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    ).thenAnswer((_) async => _unknownIncome());
    await tester.pumpWidget(_wrap(repository, locale: const Locale('en')));
    await _load(tester);

    await _tapRow(tester, 's1');
    await _tapRow(tester, 's2');
    await _settle(tester);
    expect(find.text('Compare (2/3)'), findsOneWidget);
    expect(find.text('Saved scenarios'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scenarioCompareButton')));
    await _settle(tester);

    expect(_text(tester, 'compareTitle'), 'Comparing 2 scenarios');
    expect(find.text('Indicative APR'), findsOneWidget);
    expect(find.text('With current loans'), findsOneWidget);
    expect(_text(tester, 'compare-ratio-s1'), '—');
    expect(
      find.descendant(
        of: find.byKey(const Key('compareFoot')),
        matching: find.text(
          'No known income, so no debt ratio · HCSF reference 35%. An '
          'indicative reading that binds no lender.',
        ),
      ),
      findsOneWidget,
    );
  });
}

SimulationResult _unknownIncome() => testUnknownIncomeResult();
