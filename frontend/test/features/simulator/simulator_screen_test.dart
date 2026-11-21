import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/simulator/application/simulator_controller.dart';
import 'package:bastide/features/simulator/data/simulations_repository.dart';
import 'package:bastide/features/simulator/domain/simulation.dart';
import 'package:bastide/features/simulator/presentation/simulator_screen.dart';
import 'package:bastide/features/simulator/presentation/yearly_projection_chart.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/simulator_fixtures.dart';

class MockSimulationsRepository extends Mock implements SimulationsRepository {}

String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap(
  MockSimulationsRepository repository, {
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [simulationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
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

/// The 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

/// Lets the load finish without settling: the price field's cursor blinks.
Future<void> _load(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Lets the debounce elapse and the compute answer land.
Future<void> _settleCompute(WidgetTester tester) async {
  await tester.pump(
    SimulatorController.debounce + const Duration(milliseconds: 50),
  );
  await tester.pump();
}

/// Types the frame's simulation, the rate with a French comma.
Future<void> _typeFrame(WidgetTester tester, {String rate = '3,25'}) async {
  await tester.enterText(find.byKey(const Key('simulatorPrice')), '320000');
  await tester.enterText(
    find.byKey(const Key('simulatorDownPayment')),
    '40000',
  );
  await tester.enterText(find.byKey(const Key('simulatorFees')), '4500');
  await tester.enterText(find.byKey(const Key('simulatorRate')), rate);
  await tester.enterText(find.byKey(const Key('simulatorInsurance')), '32');
  await _settleCompute(tester);
}

RepereTone _tone(WidgetTester tester, String key) =>
    tester.widget<RepereMeter>(find.byKey(Key(key))).tone;

void main() {
  late MockSimulationsRepository repository;

  setUpAll(() => registerFallbackValue(testTerms));

  setUp(() {
    repository = MockSimulationsRepository();
    when(() => repository.household()).thenAnswer((_) async => testHousehold());
    when(() => repository.list()).thenAnswer((_) async => []);
    when(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    ).thenAnswer((_) async => testResult());
  });

  void stubCompute(Object Function(bool include) answer) {
    when(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    ).thenAnswer((invocation) async {
      final include = invocation.namedArguments[#includeExistingLoans] as bool;
      final value = answer(include);
      if (value is Exception) throw value;
      return value as dynamic;
    });
  }

  testWidgets('the empty form keeps every block, drawn with a dash and its '
      'caption', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    expect(_text(tester, 'resultInstalment'), '—');
    expect(
      _text(tester, 'resultInstalmentCaption'),
      'Renseignez un prix et un taux pour voir l’échéance.',
    );
    expect(find.byKey(const Key('resultCostCaption')), findsNothing);
    expect(_text(tester, 'resultCost'), '—');
    expect(_text(tester, 'resultTaeg'), '—');
    expect(_text(tester, 'hcsfRatioValue'), '—');
    expect(_text(tester, 'hcsfCapacityValue'), '—');
    expect(_text(tester, 'hcsfTermValue'), '25 ans');
    expect(find.byKey(const Key('hcsfRatioGauge')), findsNothing);
    expect(find.byKey(const Key('projectionEmpty')), findsOneWidget);
    expect(find.byKey(const Key('projectionPlot')), findsNothing);
    expect(_text(tester, 'simulatorTermValue'), '25 ans · 300 mois');
    expect(
      _text(tester, 'simulatorIncludeExistingSub'),
      'Ajoute ${_money(150625)} par mois à la lecture',
    );
    expect(find.byKey(const Key('hcsfOverStatus')), findsNothing);
    verifyNever(
      () => repository.compute(
        any(),
        includeExistingLoans: any(named: 'includeExistingLoans'),
      ),
    );
  });

  testWidgets('typing updates the live result and saves nothing', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);

    await _typeFrame(tester);

    // The comma-typed rate reached the engine as 325 bps, and the borrowed
    // amount as its price + fees − down payment default.
    verify(
      () => repository.compute(testTerms, includeExistingLoans: false),
    ).called(1);
    verifyNever(() => repository.create(any(), any()));
    expect(_text(tester, 'resultInstalment'), _money(141841));
    expect(_text(tester, 'resultCost'), _money(14552300));
    expect(find.text('calculé : prix − apport + frais'), findsOneWidget);
    expect(find.text('284 500'.replaceAll(' ', ' ')), findsOneWidget);
  });

  testWidgets('the instalment names payment and insurance, and the TAEG is '
      'indicative', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    expect(
      _text(tester, 'resultInstalmentCaption'),
      '${_money(138641)} de mensualité + ${_money(3200)} d’assurance · '
      '300 échéances',
    );
    expect(_text(tester, 'resultTaegLabel'), 'TAEG indicatif');
    expect(_text(tester, 'resultTaeg'), startsWith('3,67'));
    expect(
      _text(tester, 'resultCostCaption'),
      'intérêts ${_money(13142300)} · assurance ${_money(960000)} · '
      'frais ${_money(450000)}',
    );
  });

  testWidgets('the projection stacks the API yearly split, one bar a year', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    final plot = tester.widget<YearlyProjectionPlot>(
      find.byKey(const Key('projectionPlot')),
    );
    final yearly = testResult().yearly;
    expect(plot.years, hasLength(25));
    expect(plot.capital, [for (final row in yearly) row.principalMinor]);
    expect(plot.interest, [for (final row in yearly) row.interestMinor]);
  });

  for (final (locale, capital, interest) in const [
    (Locale('fr'), 'Capital : ', 'Intérêts : '),
    (Locale('en'), 'Principal: ', 'Interest: '),
  ]) {
    testWidgets(
      '${locale.languageCode}: hovering a year names its split in the chart card',
      (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(_wrap(repository, locale: locale));
        await _load(tester);
        await _typeFrame(tester);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(
          tester.getCenter(find.byKey(const Key('projectionSlot-0'))),
        );
        await tester.pump();

        final row = testResult().yearly.first;
        String money(int minor) => formatAmount(
          amountMinor: minor,
          currency: 'EUR',
          locale: locale.languageCode,
        );
        final card = find.byKey(const Key('projectionTooltip'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(
              '${row.year}\n$capital${money(row.principalMinor)}\n'
              '$interest${money(row.interestMinor)}',
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );

        await gesture.moveTo(Offset.zero);
        await tester.pump();
        expect(card, findsNothing);
      },
    );
  }

  testWidgets('over the reference only the ratio repère and the status text '
      'change, and nothing is blocked', (tester) async {
    _useDesktopSurface(tester);
    stubCompute((include) => include ? testOverLimitResult() : testResult());
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    expect(find.byKey(const Key('hcsfOverStatus')), findsNothing);
    expect(_tone(tester, 'hcsfRatioGauge'), RepereTone.normal);
    final instalmentCaption = _text(tester, 'resultInstalmentCaption');

    await tester.tap(find.byKey(const Key('simulatorIncludeExisting')));
    await _settleCompute(tester);

    expect(find.byKey(const Key('hcsfOverStatus')), findsOneWidget);
    expect(_tone(tester, 'hcsfRatioGauge'), RepereTone.over);
    expect(_tone(tester, 'hcsfTermGauge'), RepereTone.normal);
    // The summary line never depends on the toggle.
    expect(_text(tester, 'resultInstalment'), _money(141841));
    expect(_text(tester, 'resultInstalmentCaption'), instalmentCaption);
    expect(_text(tester, 'hcsfRatioValue'), startsWith('63,6'));
    expect(
      _text(tester, 'hcsfRatioCaption'),
      '${_money(292466)} (${_money(141841)} + crédits actuels '
      '${_money(150625)}) sur un revenu déclaré de ${_money(460000)}',
    );
    expect(
      _text(tester, 'hcsfCapacityCaption'),
      startsWith('Vos crédits actuels laissent '),
    );
    expect(
      _text(tester, 'hcsfCapacityCaption'),
      endsWith('C’est ce qui limite la capacité, pas le bien visé.'),
    );
    expect(find.byKey(const Key('hcsfCaveat')), findsOneWidget);

    // Still a reading: the form keeps taking input.
    await tester.enterText(find.byKey(const Key('simulatorRate')), '3,40');
    await _settleCompute(tester);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('simulatorRate')),
              matching: find.byType(TextField),
            ),
          )
          .enabled,
      isNot(false),
    );
  });

  testWidgets('an unknown income states why, with no gauge and no capacity', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    when(() => repository.household()).thenAnswer(
      (_) async => testHousehold(
        monthlyIncomeMinor: null,
        incomeSource: IncomeSource.unknown,
      ),
    );
    stubCompute((_) => testUnknownIncomeResult());
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    expect(find.byKey(const Key('hcsfUnknownIncomeText')), findsOneWidget);
    expect(find.byKey(const Key('hcsfDeclareIncome')), findsOneWidget);
    expect(_text(tester, 'hcsfRatioValue'), '—');
    expect(find.byKey(const Key('hcsfRatioGauge')), findsNothing);
    expect(find.byKey(const Key('hcsfCapacityValue')), findsNothing);
    expect(find.byKey(const Key('hcsfTermGauge')), findsOneWidget);
  });

  testWidgets('a degenerate loan is explained under the rate', (tester) async {
    _useDesktopSurface(tester);
    stubCompute(
      (_) => const ApiFailure(code: 'MORTGAGE_NON_AMORTIZING', message: 'no'),
    );
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester, rate: '99');

    expect(
      find.text(
        "À ce taux, l’échéance ne rembourse pas le capital : baissez le taux "
        'ou allongez la durée.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('simulatorComputeError')), findsNothing);
    expect(_text(tester, 'resultInstalment'), '—');
  });

  testWidgets('editing the borrowed amount takes it over from the default', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository));
    await _load(tester);
    await _typeFrame(tester);

    await tester.enterText(
      find.byKey(const Key('simulatorPrincipal')),
      '250000',
    );
    await _settleCompute(tester);

    expect(find.text('calculé : prix − apport + frais'), findsNothing);
    verify(
      () => repository.compute(
        any(
          that: isA<SimulationTerms>().having(
            (terms) => terms.principalMinor,
            'principal',
            25000000,
          ),
        ),
        includeExistingLoans: false,
      ),
    ).called(1);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    _useDesktopSurface(tester);
    var offline = true;
    when(() => repository.household()).thenAnswer((_) async {
      if (offline) {
        throw const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom');
      }
      return testHousehold();
    });
    await tester.pumpWidget(_wrap(repository));
    // Riverpod retries a failed build with a backoff before settling on the
    // error; let those retries run out.
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(seconds: 10));
    }

    expect(
      _text(tester, 'simulatorErrorText'),
      'Impossible de charger le simulateur.',
    );
    offline = false;
    await tester.tap(find.byKey(const Key('simulatorRetryButton')));
    await _load(tester);

    expect(find.byKey(const Key('simulatorForm')), findsOneWidget);
  });

  testWidgets('prints the same simulation in English', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(repository, locale: const Locale('en')));
    await _load(tester);
    await _typeFrame(tester, rate: '3.25');

    verify(
      () => repository.compute(testTerms, includeExistingLoans: false),
    ).called(1);
    expect(_text(tester, 'resultInstalment'), _money(141841, locale: 'en'));
    expect(_text(tester, 'resultInstalment'), '€1,418.41');
    expect(_text(tester, 'resultTaeg'), '3.67%');
    expect(_text(tester, 'resultInstalmentLabel'), 'Monthly instalment');
    expect(_text(tester, 'resultTaegLabel'), 'Indicative APR');
    expect(_text(tester, 'simulatorTermValue'), '25 years · 300 months');
    expect(
      _text(tester, 'hcsfRatioCaption'),
      '€1,418.41 against a declared income of €4,600.00',
    );
  });

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    for (final (sidebar, width) in const [
      ('expanded', 1216.0),
      ('collapsed', 1384.0),
    ]) {
      testWidgets('$name theme, sidebar $sidebar: the two panes lay out '
          'without overflow', (tester) async {
        // The content region beside the sidebar, under the 48 px title bar.
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        stubCompute(
          (include) => include ? testOverLimitResult() : testResult(),
        );
        await tester.pumpWidget(_wrap(repository, theme: theme));
        await _load(tester);
        await _typeFrame(tester);
        await tester.tap(find.byKey(const Key('simulatorIncludeExisting')));
        await _settleCompute(tester);

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('simulatorInputsPane'))).width,
          SimulatorScreen.inputsWidth,
        );
        expect(find.byKey(const Key('hcsfOverStatus')), findsOneWidget);
        expect(find.byKey(const Key('projectionPlot')), findsOneWidget);
      });
    }
  }
}
