import 'dart:async';

import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/amount_text.dart';
import 'package:finstride/core/widgets/status_pill.dart';
import 'package:finstride/features/mortgages/application/mortgages_controller.dart';
import 'package:finstride/features/mortgages/domain/mortgage.dart';
import 'package:finstride/features/mortgages/presentation/mortgages_screen.dart';
import 'package:finstride/features/mortgages/presentation/trajectory_chart.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mortgages_fixtures.dart';

/// The panel's own money formatting, so expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required FakeMortgagesController controller,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      mortgagesControllerProvider.overrideWith(() => controller),
      mortgagesTodayProvider.overrideWithValue(() => mortgagesToday),
      loanPropertiesProvider.overrideWith((ref) => const <LoanProperty>[]),
      mortgageDetailProvider.overrideWith(
        (ref, id) async => MortgageDetailView(
          detail: testDetail(),
          interestStillDueMinor: 9240674,
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MortgagesTopBarActions(),
            Expanded(child: MortgagesScreen()),
          ],
        ),
      ),
    ),
  );
}

/// The 1440×900 desktop frame the design targets, less the shell's 72 px top
/// bar the panel sits under.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440 - 252, 900 - 72);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

FakeMortgagesController _twoLoans({MortgageSummary? summary}) =>
    FakeMortgagesController(
      initialMortgages: [testMortgage(), testWorksLoan()],
      summary: summary,
    );

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

class _PendingController extends FakeMortgagesController {
  @override
  Future<MortgagesState> build() => Completer<MortgagesState>().future;
}

void main() {
  group('loan cards', () {
    testWidgets('print neutral figures, formatted in French', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mortgageCard-m1')), findsOneWidget);
      expect(find.byKey(const Key('mortgageCard-m2')), findsOneWidget);
      expect(
        _text(tester, 'mortgageCardSubline-m1'),
        'Crédit immobilier · BNP · 300 mois',
      );
      expect(
        _text(tester, 'mortgageCardSubline-m2'),
        'Prêt travaux · Crédit Agricole · 60 mois',
      );

      // A scheduled charge, not a booked transaction: never the ledger's red.
      final instalment = tester.widget<AmountText>(
        find.byKey(const Key('mortgageCardInstalment-m1')),
      );
      expect(instalment.amountMinor, 122387);
      expect(instalment.colorize, isFalse);
      final outstanding = tester.widget<AmountText>(
        find.byKey(const Key('mortgageCardOutstanding-m1')),
      );
      expect(outstanding.amountMinor, 22254270);
      expect(outstanding.colorize, isFalse);

      expect(_text(tester, 'mortgageCardRate-m1'), startsWith('3,45'));
      expect(_text(tester, 'mortgageCardRepaid-m1'), startsWith('7,3'));
      expect(
        _text(tester, 'mortgageCardRemaining-m1'),
        '267 échéances restantes',
      );
      expect(
        _text(tester, 'mortgageCardInsurance-m1'),
        '${_money(2880)} / mois',
      );
      expect(_text(tester, 'mortgageCardInsurance-m2'), '—');
      expect(_text(tester, 'mortgageCardNext-m1'), '01/06/2026');
    });

    testWidgets('print the same figures in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: _twoLoans(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(
        _text(tester, 'mortgageCardSubline-m1'),
        'Home loan · BNP · 300 months',
      );
      expect(_text(tester, 'mortgageCardRate-m1'), '3.45%');
      expect(_text(tester, 'mortgageCardRepaid-m1'), '7.3%');
      expect(_text(tester, 'mortgageCardRemaining-m1'), '267 instalments left');
      expect(
        _text(tester, 'mortgageCardInsurance-m1'),
        '${_money(2880, locale: 'en')} / month',
      );
      expect(_text(tester, 'mortgageCardNext-m1'), '6/1/2026');
    });

    testWidgets('a card opens the loan detail', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mortgageCard-m1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mortgageDetail')), findsOneWidget);
      expect(find.byKey(const Key('mortgageTaegIndicative')), findsOneWidget);
    });
  });

  group('debt ratio card', () {
    testWidgets('a declared income draws the gauge and names its source', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ratioGauge')), findsOneWidget);
      expect(find.byKey(const Key('ratioOverLimitPill')), findsNothing);
      expect(_text(tester, 'ratioValue'), startsWith('32,7'));
      expect(
        _text(tester, 'ratioCaption'),
        'Charge ${_money(150625)} sur un revenu déclaré de ${_money(460000)}',
      );
      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('ratioGaugeFill')),
      );
      expect(fill.widthFactor, closeTo(3274 / 6000, 1e-9));
      expect((fill.child! as ColoredBox).color, AppColors.iris);
      // Body content, not a tooltip.
      expect(
        _text(tester, 'ratioCaveat'),
        'Lecture informative : ce repère ne lie aucun prêteur.',
      );
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets(
      'a ledger income above the reference warns in amber and blocks nothing',
      (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            controller: _twoLoans(
              summary: testMortgageSummary(
                incomeSource: IncomeSource.ledger,
                debtRatioBps: 5285,
                monthlyIncomeMinor: 285000,
                overLimit: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pill = tester.widget<StatusPill>(
          find.byKey(const Key('ratioOverLimitPill')),
        );
        expect(pill.tone, StatusPillTone.warning);
        expect(pill.label, 'Au-dessus du repère');
        final fill = tester.widget<FractionallySizedBox>(
          find.byKey(const Key('ratioGaugeFill')),
        );
        expect((fill.child! as ColoredBox).color, AppColors.warning);
        expect(
          _text(tester, 'ratioCaption'),
          contains('revenu médian constaté'),
        );
        expect(find.byKey(const Key('ratioDeclareIncomeLink')), findsOneWidget);

        // Information, never a block: creating a loan and opening one still work.
        await tester.tap(find.byKey(const Key('addMortgageButton')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mortgageFormSubmit')), findsOneWidget);
        await tester.tap(find.byKey(const Key('mortgageFormCancel')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mortgageCard-m2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mortgageDetail')), findsOneWidget);
      },
    );

    testWidgets('an unknown income draws no gauge and offers to declare one', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final controller = _twoLoans(
        summary: testMortgageSummary(
          incomeSource: IncomeSource.unknown,
          debtRatioBps: null,
          monthlyIncomeMinor: null,
        ),
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ratioGauge')), findsNothing);
      expect(_text(tester, 'ratioValue'), '—');
      expect(find.byKey(const Key('ratioUnknownText')), findsOneWidget);
      expect(find.byKey(const Key('ratioCaveat')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ratioDeclareIncomeButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('declareIncomeAmount')),
        '4600',
      );
      await tester.tap(find.byKey(const Key('declareIncomeSubmit')));
      await tester.pumpAndSettle();

      expect(controller.declaredIncomes, [460000]);
    });

    testWidgets(
      'a ratio past 60 % clamps the fill and still prints the exact figure',
      (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            controller: _twoLoans(
              summary: testMortgageSummary(debtRatioBps: 7200, overLimit: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fill = tester.widget<FractionallySizedBox>(
          find.byKey(const Key('ratioGaugeFill')),
        );
        expect(fill.widthFactor, 1.0);
        expect(_text(tester, 'ratioValue'), startsWith('72,0'));
      },
    );
  });

  testWidgets(
    'the trajectory chart draws the API series with today and each end',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      final plot = tester.widget<TrajectoryPlot>(
        find.byKey(const Key('trajectoryPlot')),
      );
      expect(plot.values, [24000000, 25500000, 23412921, 19000000, 0]);
      expect(plot.annotations.map((annotation) => annotation.label), [
        'mai 2026 · ${_money(23412921)}',
        'fin prêt travaux · 02/2030',
        'fin crédit immobilier · 08/2048',
      ]);
      expect(plot.annotations.first.isToday, isTrue);
    },
  );

  testWidgets('no loans shows the empty state without summary or chart', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeMortgagesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mortgagesEmptyState')), findsOneWidget);
    expect(find.text('Aucun crédit enregistré'), findsOneWidget);
    expect(find.byKey(const Key('mortgagesEmptyCta')), findsOneWidget);
    expect(find.byKey(const Key('debtRatioCard')), findsNothing);
    expect(find.byKey(const Key('trajectoryChartCard')), findsNothing);
  });

  testWidgets('loading shows the skeleton silhouettes', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: _PendingController()));
    await tester.pump();

    expect(find.byKey(const Key('mortgagesLoading')), findsOneWidget);
  });

  testWidgets('a load failure shows the retry state', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeMortgagesController(loadError: Exception('offline')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mortgagesErrorText')), findsOneWidget);
    expect(find.byKey(const Key('mortgagesRetryButton')), findsOneWidget);
  });
}
