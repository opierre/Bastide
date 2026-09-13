import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/features/simulator/application/simulator_controller.dart';
import 'package:finstride/features/simulator/data/simulations_repository.dart';
import 'package:finstride/features/simulator/domain/simulation.dart';
import 'package:finstride/features/simulator/domain/simulation_result.dart';
import 'package:finstride/features/simulator/presentation/simulator_labels.dart';
import 'package:finstride/features/simulator/presentation/simulator_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
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
      theme: appDarkTheme,
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

/// Scrolls a scenario row into the list's viewport, then taps it — at 900 px
/// the list shows only its first rows, as a user would find it.
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
  testScenario(id: 's2', label: 'Lyon 7e — 350 k€'),
  testScenario(id: 's3', label: 'Lyon 8e — 290 k€'),
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

  testWidgets('with nothing saved the card is a mini empty state with no '
      'compare control', (tester) async {
    _useDesktopSurface(tester);
    when(() => repository.list()).thenAnswer((_) async => []);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    expect(find.byKey(const Key('scenariosEmpty')), findsOneWidget);
    expect(find.text('Aucun scénario enregistré'), findsOneWidget);
    expect(find.byKey(const Key('scenarioCompareButton')), findsNothing);
  });

  testWidgets('saving names the inputs on the place — price pattern, even '
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
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNull);

    await _typeFrame(tester);
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await _settle(tester);

    final nameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('saveScenarioName')),
        matching: find.byType(EditableText),
      ),
    );
    expect(nameField.controller.text, ' — 320 k€');
    expect(nameField.controller.selection.baseOffset, 0);

    await tester.enterText(
      find.byKey(const Key('saveScenarioName')),
      'Lyon 3e — 320 k€',
    );
    await tester.tap(find.byKey(const Key('saveScenarioSubmit')));
    await _settle(tester);

    verify(() => repository.create('Lyon 3e — 320 k€', testTerms)).called(1);
    expect(find.byKey(const Key('saveScenarioName')), findsNothing);
    expect(_text(tester, 'scenarioName-s9'), 'Lyon 3e — 320 k€');
  });

  testWidgets('the live row comes first, marked EN COURS', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    final live = tester.getTopLeft(find.byKey(const Key('scenarioRow-live')));
    final saved = tester.getTopLeft(find.byKey(const Key('scenarioRow-s1')));
    expect(live.dy, lessThan(saved.dy));
    expect(_text(tester, 'scenarioName-live'), '320 k€');
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('scenarioLivePill')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'EN COURS',
    );
    expect(
      _text(tester, 'scenarioSub-s1'),
      '${formatRate(325, 'fr')} · 25 ans · '
      '${formatAmount(amountMinor: 141841, currency: 'EUR', locale: 'fr')}',
    );
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

  testWidgets('compare takes three with the live row, then dims the rest and '
      'says how to free a slot', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    OutlinedButton compare() => tester.widget<OutlinedButton>(
      find.byKey(const Key('scenarioCompareButton')),
    );

    await _tapRow(tester, 'live');
    await _settle(tester);
    expect(compare().onPressed, isNull);
    expect(
      _text(tester, 'scenarioNote'),
      'Cochez au moins deux scénarios pour les comparer.',
    );

    await _tapRow(tester, 's1');
    await _tapRow(tester, 's2');
    await _settle(tester);

    expect(find.text('Comparer (3/3)'), findsOneWidget);
    expect(compare().onPressed, isNotNull);
    final dimmed = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('scenarioRow-s3')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dimmed.opacity, 0.5);
    expect(
      _text(tester, 'scenarioNote'),
      'Trois scénarios au plus, pour rester lisibles côte à côte. '
      'Décochez-en un pour ajouter Lyon 8e — 290 k€.',
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

    expect(find.byKey(const Key('compareCard')), findsOneWidget);
    expect(find.byKey(const Key('hcsfCard')), findsNothing);
    expect(_text(tester, 'compareTitle'), 'Comparaison de 3 scénarios');
    expect(_text(tester, 'compareHeader-live'), 'Simulation en cours');
    expect(_text(tester, 'compareHeader-s1'), 'Villeurbanne — 265 k€');

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
    expect(_text(tester, 'compareFoot'), contains('ne lie aucun prêteur'));
    // Every column carries every row.
    for (final id in ['live', 's1', 's2']) {
      expect(find.byKey(Key('compare-ratioWithExisting-$id')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('compareClose')));
    await _settle(tester);
    expect(find.byKey(const Key('compareCard')), findsNothing);
    expect(find.byKey(const Key('hcsfCard')), findsOneWidget);
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
      _text(tester, 'compareFoot'),
      'No known income, so no debt ratio · HCSF reference 35% · an '
      'informative reading that binds no lender.',
    );
  });
}

SimulationResult _unknownIncome() => testUnknownIncomeResult();
