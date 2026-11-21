import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/features/placements/domain/investment.dart';
import 'package:bastide/features/placements/presentation/placements_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/placements_fixtures.dart';

String _money(int minor, {String locale = 'fr', bool signed = false}) =>
    formatAmount(
      amountMinor: minor,
      currency: 'EUR',
      locale: locale,
      showPositiveSign: signed,
    );

Widget _wrap(
  FakePlacementsController controller, {
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  Map<String, InvestmentDetail> details = const {},
}) => ProviderScope(
  overrides: placementsOverrides(controller, details: details),
  child: MaterialApp(
    locale: locale,
    theme: theme ?? AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: PlacementsScreen()),
  ),
);

/// The 1440 × 900 frame less the sidebar: 224 px expanded, 56 collapsed.
void _useSurface(WidgetTester tester, {double width = 1216}) {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _inInspector(Finder finder) => find.descendant(
  of: find.byKey(const Key('placementInspector')),
  matching: finder,
);

String _text(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(Key(key)));
  return switch (widget) {
    Text(:final data?) => data,
    Text(:final textSpan?) => textSpan.toPlainText(),
    RichText(:final text) => text.toPlainText(),
    _ => throw StateError('$key is not text'),
  };
}

void main() {
  testWidgets('the summary line, the table and the first one selected', (
    tester,
  ) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(FakePlacementsController(investments: specInvestments())),
    );
    await tester.pumpAndSettle();

    expect(_text(tester, 'placementsSummaryValue'), _money(5423500));
    expect(
      _text(tester, 'placementsSummaryCaption'),
      '3 placements · dernière valeur saisie le 30 avr. 2026',
    );
    expect(_text(tester, 'placementsSummaryNetPayments'), _money(4670000));
    expect(
      _text(tester, 'placementsSummaryGain'),
      _money(753500, signed: true),
    );
    expect(find.text('+16,1 % des versements'), findsOneWidget);

    for (final header in [
      'Placement',
      'Versements nets',
      'Valeur déclarée',
      'Plus-value',
      'Valeur au',
    ]) {
      expect(find.text(header), findsWidgets);
    }
    expect(
      _text(tester, 'placementSubtitle-i1'),
      'PEA · Courtier Nord · ouvert en mars 2023',
    );
    expect(_text(tester, 'placementValue-i1'), _money(3184000));
    expect(
      _text(tester, 'placementGain-i1'),
      '${_money(484000, signed: true)} +17,9 %',
    );

    final first = tester.widget<AppTableRow>(
      find.byKey(const Key('placementRow-i1')),
    );
    expect(first.selected, isTrue);
    expect(first.twoLines, isTrue);
    expect(_inInspector(find.text('PEA')), findsOneWidget);
    expect(
      _inInspector(find.text('Courtier Nord · ouvert le 14 mars 2023')),
      findsOneWidget,
    );
    expect(_inInspector(find.text('au 30 avr. 2026')), findsOneWidget);
    expect(find.text('Saisir la valeur'), findsOneWidget);
    expect(find.text('Versement ou retrait'), findsOneWidget);

    // The PEA's two repères: its ceiling, and its age with the milestone.
    expect(
      _text(tester, 'placementCeilingValue-i1'),
      '${_money(2700000)} sur ${_money(15000000)}',
    );
    expect(_text(tester, 'placementAgeValue-i1'), '3 ans 2 mois');
    final age = tester.widget<RepereMeter>(
      find.byKey(const Key('placementAgeMeter-i1')),
    );
    expect(age.markLabel, 'repère 5 ans · mars 2028');
    expect(age.tone, RepereTone.normal);
    expect(
      find.text(
        'Avant 5 ans, un retrait clôt en principe le plan. Lecture '
        'indicative, qui ne vaut pas conseil fiscal.',
      ),
      findsOneWidget,
    );

    // The history: newest first, values unsigned, payments signed.
    expect(find.byKey(const Key('placementHistoryRow-v2')), findsOneWidget);
    expect(_inInspector(find.text('Valeur saisie')), findsNWidgets(2));
    expect(_inInspector(find.text(_money(50000, signed: true))), findsOne);
    expect(_inInspector(find.text('Versement · Ouverture')), findsOneWidget);

    expect(
      find.text(
        'Bastide ne se connecte à aucun courtier et ne télécharge aucun '
        'cours. La valeur est celle que vous recopiez depuis votre relevé. '
        'La plus-value est calculée, jamais enregistrée.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale value: the warning date and its banner', (tester) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placementStaleBanner-i3')), findsOneWidget);
    expect(
      find.text('La valeur du PEE Entreprise date de plus de quatre mois.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('placementStaleBanner-i1')), findsNothing);

    await tester.tap(find.byKey(const Key('placementStaleAction-i3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('valuationModal')), findsOneWidget);
    expect(
      find.text('Recopiez la valeur totale indiquée sur votre relevé.'),
      findsOneWidget,
    );
  });

  testWidgets('more than three stale values: three banners, then a count', (
    tester,
  ) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(
          investments: [
            for (var i = 1; i <= 5; i++)
              testInvestment(id: 'i$i', name: 'PEA $i', valueStale: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('date de plus de quatre mois'),
      findsNWidgets(3),
    );
    expect(_text(tester, 'placementsStaleMore'), 'et 2 autres');
  });

  testWidgets('selecting a row shows that placement in the inspector', (
    tester,
  ) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(FakePlacementsController(investments: specInvestments())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementRow-i2')));
    await tester.pumpAndSettle();

    expect(_inInspector(find.text('Assurance vie Horizon')), findsOneWidget);
    // No ceiling for a life insurance; its 8-year milestone is reached.
    expect(find.byKey(const Key('placementCeilingMeter-i2')), findsNothing);
    expect(
      tester
          .widget<RepereMeter>(find.byKey(const Key('placementAgeMeter-i2')))
          .tone,
      RepereTone.done,
    );
    expect(
      find.text(
        'Après 8 ans, la fiscalité des retraits s’allège. Lecture indicative, '
        'qui ne vaut pas conseil fiscal.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a declared value: dashes and the note', (tester) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(
          investments: [testInvestment(lastValueMinor: null)],
          summary: testInvestmentSummary(
            declaredValueMinor: 0,
            unrealisedGainMinor: 0,
            gainBps: null,
            valuedCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_text(tester, 'placementValue-i1'), '—');
    expect(_text(tester, 'placementGain-i1'), '—');
    expect(_text(tester, 'placementsSummaryGain'), '—');
    expect(_text(tester, 'placementsSummaryCaption'), '3 placements');
    expect(_text(tester, 'placementInspectorValue-i1'), '—');
    expect(
      find.text('Saisissez une valeur pour voir la plus-value.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loss reads with its minus, still neutral', (tester) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(
          investments: [testInvestment(lastValueMinor: 2500000)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_text(tester, 'placementGain-i1'), '${_money(-200000)} −7,4 %');
    final gain = tester.widget<Text>(find.byKey(const Key('placementGain-i1')));
    expect(gain.style?.color, AppTheme.dark.extension<AppColors>()!.text);
  });

  testWidgets('the ceiling reached: the repère over and its caption', (
    tester,
  ) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(
          investments: [
            testInvestment(paidInMinor: 15000000, lastValueMinor: 16000000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<RepereMeter>(
            find.byKey(const Key('placementCeilingMeter-i1')),
          )
          .tone,
      RepereTone.over,
    );
    expect(find.text('Plafond de versement atteint.'), findsOneWidget);
  });

  testWidgets('a closed placement is dimmed and offers « Rouvrir »', (
    tester,
  ) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(
          investments: [testInvestment(closedOn: DateTime(2026, 2, 1))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppTableRow>(find.byKey(const Key('placementRow-i1')))
          .dimmed,
      isTrue,
    );
    expect(find.text('Saisir la valeur'), findsNothing);

    await tester.tap(find.byKey(const Key('placementMenu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placementMenu-reopen')), findsOneWidget);
    expect(find.byKey(const Key('placementMenu-close')), findsNothing);
  });

  testWidgets('entering a value submits it for the selected placement', (
    tester,
  ) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementEnterValue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('valuationValue')), '32000');
    await tester.enterText(find.byKey(const Key('valuationNote')), 'Relevé');
    await tester.tap(find.byKey(const Key('valuationSubmit')));
    await tester.pumpAndSettle();

    final (id, _, value, note) = controller.valuationCalls.single;
    expect(id, 'i1');
    expect(value, 3200000);
    expect(note, 'Relevé');
    expect(find.byKey(const Key('valuationModal')), findsNothing);
  });

  testWidgets('a withdrawal is entered as a negative amount', (tester) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementAddMovement')));
    await tester.pumpAndSettle();
    expect(find.text('Un montant négatif est un retrait.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('movementAmount')), '-250');
    await tester.tap(find.byKey(const Key('movementSubmit')));
    await tester.pumpAndSettle();

    expect(controller.movementCalls.single.$3, -25000);
  });

  testWidgets('a refused value stays in the modal with its reason', (
    tester,
  ) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments())
      ..errorOnWrite = const ApiFailure(
        code: 'INVESTMENT_VALUATION_EXISTS',
        message: 'taken',
      );
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementEnterValue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('valuationValue')), '100');
    await tester.tap(find.byKey(const Key('valuationSubmit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('valuationModal')), findsOneWidget);
    expect(
      find.text(
        'Une valeur est déjà saisie à cette date. Modifiez-la depuis les '
        'mouvements.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('« Nouveau placement » creates with its opening history', (
    tester,
  ) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(
      ProviderScope(
        overrides: placementsOverrides(controller),
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                PlacementsTopBarActions(),
                Expanded(child: PlacementsScreen()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addPlacementButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('placementFormName')), 'PER');
    await tester.enterText(
      find.byKey(const Key('placementFormInstitution')),
      'Courtier Nord',
    );
    await tester.enterText(
      find.byKey(const Key('placementFormOpenedOn')),
      '02/01/2024',
    );
    await tester.enterText(
      find.byKey(const Key('placementFormPayments')),
      '1000',
    );
    await tester.tap(find.byKey(const Key('placementFormEnvelope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PER').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placementFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single, {
      'name': 'PER',
      'institution': 'Courtier Nord',
      'envelope': Envelope.per,
      'opened_on': DateTime(2024, 1, 2),
      'payments': 100000,
      'value': null,
    });
  });

  testWidgets('closing asks the date and the final amount', (tester) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placementMenu-close')));
    await tester.pumpAndSettle();
    expect(
      find.text('PEA quitte la synthèse à cette date et reste listé.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('closePlacementAmount')),
      '31840',
    );
    await tester.tap(find.byKey(const Key('closePlacementSubmit')));
    await tester.pumpAndSettle();

    expect(controller.closeCalls.single.$3, 3184000);
  });

  testWidgets('deleting says the history goes and asks first', (tester) async {
    _useSurface(tester);
    final controller = FakePlacementsController(investments: specInvestments());
    await tester.pumpWidget(_wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placementMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placementMenu-delete')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'PEA et tout son historique seront supprimés. Pour le garder, '
        'clôturez-le.',
      ),
      findsOneWidget,
    );
    expect(controller.deleteCalls, isEmpty);
    await tester.tap(find.byKey(const Key('deletePlacementSubmit')));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, ['i1']);
  });

  testWidgets('no placement: the empty state with its button', (tester) async {
    _useSurface(tester);
    await tester.pumpWidget(_wrap(FakePlacementsController()));
    await tester.pumpAndSettle();

    expect(find.text('Aucun placement'), findsOneWidget);
    expect(
      find.text(
        'Suivez un PEA, une assurance vie ou un autre placement à partir des '
        'valeurs de vos relevés.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('placementsEmptyAddButton')), findsOneWidget);
    expect(find.byKey(const Key('placementInspector')), findsNothing);
  });

  testWidgets('loading draws the silhouette of both panes', (tester) async {
    _useSurface(tester);
    final controller = _NeverLoads();
    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    expect(find.byKey(const Key('placementsLoadingIndicator')), findsOneWidget);
  });

  testWidgets('a failed load says so and retries', (tester) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(FakePlacementsController(loadError: ApiFailure.unknown())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Les placements n’ont pas pu être chargés. Rien n’a été modifié.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('placementsRetryButton')), findsOneWidget);
  });

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    for (final (sidebar, width) in [
      ('expanded', 1216.0),
      ('collapsed', 1384.0),
    ]) {
      testWidgets('$name theme, sidebar $sidebar: lays out without overflow', (
        tester,
      ) async {
        _useSurface(tester, width: width);
        await tester.pumpWidget(
          _wrap(
            FakePlacementsController(investments: specInvestments()),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('placementInspector')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('renders in English with no leftover French', (tester) async {
    _useSurface(tester);
    await tester.pumpWidget(
      _wrap(
        FakePlacementsController(investments: specInvestments()),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Declared value'), findsWidgets);
    expect(find.text('Net payments'), findsWidgets);
    expect(find.text('Unrealised gain'), findsOneWidget);
    expect(find.text('Enter a value'), findsOneWidget);
    expect(find.text('Movements'), findsOneWidget);
    expect(find.textContaining('Versement'), findsNothing);
    expect(find.textContaining('Valeur'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// A controller whose load never finishes: the panel stays on its
/// silhouette.
class _NeverLoads extends FakePlacementsController {
  @override
  Future<Never> build() => Completer<Never>().future;
}
