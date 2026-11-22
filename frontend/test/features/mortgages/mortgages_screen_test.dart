import 'dart:async';

import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/repere_meter.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/mortgages/application/mortgages_controller.dart';
import 'package:bastide/features/mortgages/domain/mortgage.dart';
import 'package:bastide/features/mortgages/presentation/mortgage_labels.dart';
import 'package:bastide/features/mortgages/presentation/mortgages_screen.dart';
import 'package:bastide/features/mortgages/presentation/trajectory_chart.dart';
import 'package:bastide/features/settings/presentation/settings_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/mortgages_fixtures.dart';

/// The panel's own money formatting, so expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

/// The panel's own percent formatting, for the same reason.
String _pct(int bps, {int digits = 1}) => formatBps(bps, 'fr', digits: digits);

const _caveat = 'Lecture indicative, qui n’engage aucun prêteur.';

/// The panel as the shell lays it out: the title and the title-bar controls
/// above the content region. Routed, so « Déclarer un revenu » can leave for
/// Paramètres.
Widget _wrap({
  required FakeMortgagesController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  final router = GoRouter(
    initialLocation: MortgagesScreen.path,
    routes: [
      GoRoute(
        path: MortgagesScreen.path,
        builder: (context, state) => const Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: MortgagesTitle()),
                  MortgagesTopBarActions(),
                ],
              ),
              Expanded(child: MortgagesScreen()),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        // Prints the location it was opened at, so a test can tell the
        // Revenu déclaré deep link from a plain visit.
        builder: (context, state) => Scaffold(
          body: Text(state.uri.toString(), key: const Key('settingsRoute')),
        ),
      ),
    ],
  );
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
      scheduleWindowProvider.overrideWith(
        (ref, window) async => testScheduleYear(year: window.year),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// The 1440×900 desktop frame the design targets.
void _useDesktopSurface(WidgetTester tester, {double width = 1440}) {
  tester.view.physicalSize = Size(width, 900);
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

String _richText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).textSpan!.toPlainText();

class _PendingController extends FakeMortgagesController {
  @override
  Future<MortgagesState> build() => Completer<MortgagesState>().future;
}

void main() {
  group('summary line', () {
    testWidgets('leads with the charge, then the outstanding principal', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(_text(tester, 'mortgagesMonthlyCharge'), _money(150625));
      expect(
        _text(tester, 'mortgagesChargeCaption'),
        '2 échéances le 1\u00A0juin 2026, assurance comprise',
      );
      expect(_text(tester, 'mortgagesTotalOutstanding'), _money(23412921));
      expect(
        _text(tester, 'mortgagesOutstandingCaption'),
        'sur ${_money(25500000)} · ${_pct(818)} remboursés',
      );
      // No tinted hero, no card: the figures are set in type.
      expect(find.byKey(const Key('debtRatioCard')), findsNothing);
    });
  });

  group('loans table', () {
    testWidgets('prints neutral figures, formatted in French', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanRow-m1')), findsOneWidget);
      expect(find.byKey(const Key('loanRow-m2')), findsOneWidget);
      expect(_text(tester, 'loanName-m1'), 'Appartement Lyon 3e');
      expect(_text(tester, 'loanLender-m1'), 'BNP · 300 mois');
      expect(_text(tester, 'loanLender-m2'), 'Crédit Agricole · 60 mois');
      expect(_text(tester, 'loanRate-m1'), _pct(345, digits: 2));
      expect(_text(tester, 'loanInsurance-m1'), _money(2880));
      expect(_text(tester, 'loanInsurance-m2'), '—');
      expect(
        _text(tester, 'loanRepaid-m1'),
        '${_pct(727)} · 267 échéances restantes',
      );
      expect(_text(tester, 'loanOutstanding-m1'), _money(22254270));
      expect(_text(tester, 'loanEnd-m1'), 'août 2048');
      expect(_text(tester, 'loanEnd-m2'), 'févr. 2030');
      expect(_text(tester, 'loanInstalment-m1'), _money(122387));

      final meter = tester.widget<RepereMeter>(
        find.byKey(const Key('loanRepaidMeter-m1')),
      );
      expect(meter.fraction, closeTo(0.0727, 1e-9));
      expect(meter.markFraction, isNull);

      // A scheduled amount, not a booked transaction: never the ledger's red.
      final instalment = tester.widget<Text>(
        find.byKey(const Key('loanInstalment-m1')),
      );
      expect(instalment.style?.color, isNull);
    });

    testWidgets('prints the same figures in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(controller: _twoLoans(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(_text(tester, 'loanLender-m1'), 'BNP · 300 months');
      expect(_text(tester, 'loanRate-m1'), '3.45%');
      expect(_text(tester, 'loanRepaid-m1'), '7.3% · 267 instalments left');
      expect(_text(tester, 'loanEnd-m1'), 'Aug 2048');
      expect(
        _text(tester, 'mortgagesChargeCaption'),
        '2 instalments on June\u00A01, 2026, insurance included',
      );
    });

    testWidgets('a row opens the loan detail with its crumb and « Modifier »', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addMortgageButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('loanRow-m1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mortgageDetail')), findsOneWidget);
      expect(find.byKey(const Key('mortgageDetailTitle')), findsOneWidget);
      expect(_text(tester, 'titleBarCrumb'), 'Crédits');
      expect(_text(tester, 'titleBarTitle'), 'Appartement Lyon 3e');
      expect(find.byKey(const Key('addMortgageButton')), findsNothing);
      final edit = tester.widget<AppButton>(
        find.byKey(const Key('mortgageDetailEdit')),
      );
      expect(edit.variant, AppButtonVariant.secondary);
      expect(edit.label, 'Modifier');

      // The crumb leads back to the list.
      await tester.tap(find.byKey(const Key('titleBarCrumb')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loansTable')), findsOneWidget);
    });
  });

  group('loan detail', () {
    testWidgets('sets the instalment, the cost line and the terms in type', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('loanRow-m1')));
      await tester.pumpAndSettle();

      expect(_text(tester, 'mortgageDetailInstalment'), _money(122387));
      expect(
        _text(tester, 'mortgageDetailInstalmentCaption'),
        '${_money(119507)} + ${_money(2880)} d’assurance',
      );
      expect(_text(tester, 'mortgageDetailNext'), '1\u00A0juin 2026');
      expect(
        _text(tester, 'mortgageDetailFacts'),
        'Crédit immobilier · BNP · ${_money(24000000)} sur 300 mois',
      );
      expect(
        _text(tester, 'mortgageDetailFirstPayment'),
        '1re échéance le 1\u00A0sept. 2023 · frais de dossier ${_money(145000)}',
      );
      expect(find.text('TAEG indicatif'), findsOneWidget);
      expect(find.text('taux, assurance et frais'), findsOneWidget);
      expect(_text(tester, 'mortgageCostRate'), _pct(345, digits: 2));
      expect(_text(tester, 'mortgageCostTaeg'), _pct(379, digits: 2));
      expect(_text(tester, 'mortgageCostTotal'), _money(12861100));
      expect(find.byKey(const Key('scheduleTable')), findsOneWidget);
    });
  });

  group('debt ratio', () {
    testWidgets('a declared income draws the repère and names its source', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ratioOverLimit')), findsNothing);
      expect(_text(tester, 'ratioValue'), _pct(3274));
      expect(
        _richText(tester, 'ratioCaption'),
        '${_money(150625)} sur un revenu déclaré de ${_money(460000)}. '
        '$_caveat',
      );
      final meter = tester.widget<RepereMeter>(
        find.byKey(const Key('ratioGauge')),
      );
      expect(meter.fraction, closeTo(3274 / 6000, 1e-9));
      expect(meter.tone, RepereTone.normal);
      expect(meter.markFraction, closeTo(3500 / 6000, 1e-9));
      expect(meter.markLabel, 'repère HCSF ${_pct(3500, digits: 0)}');
      expect(
        tester.getSize(find.byKey(const Key('debtRatioItem'))).width,
        AppLoans.ratioWidth,
      );
      // Body text, never a tooltip.
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byKey(const Key('ratioDeclareIncomeLink')), findsNothing);
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

        final status = tester.widget<StatusText>(
          find.byKey(const Key('ratioOverLimit')),
        );
        expect(status.tone, StatusTone.warning);
        expect(status.label, 'Au-dessus du repère');
        final meter = tester.widget<RepereMeter>(
          find.byKey(const Key('ratioGauge')),
        );
        expect(meter.tone, RepereTone.over);
        expect(
          _richText(tester, 'ratioCaption'),
          '${_money(150625)} sur un revenu médian constaté de '
          '${_money(285000)} (12 mois). Un revenu déclaré remplace cette '
          'lecture. $_caveat',
        );
        // The figure stays neutral: the status text carries the warning.
        final value = tester.widget<Text>(find.byKey(const Key('ratioValue')));
        expect(value.style?.color, AppColors.dark.text);

        // Information, never a block: creating and opening a loan still work.
        await tester.tap(find.byKey(const Key('addMortgageButton')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mortgageFormSubmit')), findsOneWidget);
        await tester.tap(find.byKey(const Key('mortgageFormCancel')));
        await tester.pumpAndSettle();

        // « Déclarer un revenu » opens Paramètres on the Revenu déclaré field.
        await tester.tap(find.byKey(const Key('ratioDeclareIncomeLink')));
        await tester.pumpAndSettle();
        expect(_text(tester, 'settingsRoute'), SettingsScreen.incomePath);
      },
    );

    testWidgets('an unknown income draws no repère and offers to declare one', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: _twoLoans(
            summary: testMortgageSummary(
              incomeSource: IncomeSource.unknown,
              debtRatioBps: null,
              monthlyIncomeMinor: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ratioGauge')), findsNothing);
      expect(_text(tester, 'ratioValue'), '—');
      expect(
        tester.widget<Text>(find.byKey(const Key('ratioValue'))).style?.color,
        AppColors.dark.textTertiary,
      );
      // The HCSF sentence stays.
      expect(
        _richText(tester, 'ratioCaption'),
        'Aucun revenu connu. Sans revenu, il n’y a pas de taux à calculer. '
        '$_caveat',
      );

      final declare = tester.widget<AppButton>(
        find.byKey(const Key('ratioDeclareIncomeButton')),
      );
      expect(declare.variant, AppButtonVariant.secondary);
      await tester.tap(find.byKey(const Key('ratioDeclareIncomeButton')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'settingsRoute'), SettingsScreen.incomePath);
    });

    testWidgets('past 60 % the fill clamps and the figure stays exact', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: _twoLoans(
            summary: testMortgageSummary(debtRatioBps: 7200, overLimit: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The meter clamps its fill; it is handed the exact position.
      final meter = tester.widget<RepereMeter>(
        find.byKey(const Key('ratioGauge')),
      );
      expect(meter.fraction, closeTo(7200 / 6000, 1e-9));
      expect(_text(tester, 'ratioValue'), _pct(7200));
    });
  });

  testWidgets(
    'the trajectory draws the API series with today and each loan end',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      expect(
        find.text('Capital restant dû jusqu’au dernier remboursement'),
        findsOneWidget,
      );
      final plot = tester.widget<TrajectoryPlot>(
        find.byKey(const Key('trajectoryPlot')),
      );
      expect(plot.values, [24000000, 25500000, 23412921, 19000000, 0]);
      expect(plot.annotations.map((annotation) => annotation.label), [
        'mai 2026 · ${_money(23412921)}',
        'fin du prêt travaux',
        'fin du crédit immobilier',
      ]);
      expect(plot.annotations.first.isToday, isTrue);
    },
  );

  testWidgets(
    'hovering the trajectory names the nearest month in the chart card',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: _twoLoans()));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      // The plot's right edge: the last instalment, nothing left owed.
      final plot = tester.getRect(find.byKey(const Key('trajectoryPlot')));
      await gesture.moveTo(
        plot.centerRight - const Offset(AppChart.dotReach, 0),
      );
      await tester.pump();

      final card = find.byKey(const Key('trajectoryTooltip'));
      expect(card, findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(_money(0), findRichText: true),
        ),
        findsOneWidget,
      );

      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(card, findsNothing);
    },
  );

  testWidgets('renders in the light theme and in English, sidebar collapsed', (
    tester,
  ) async {
    // The content region beside the 56 px collapsed sidebar.
    _useDesktopSurface(tester, width: 1440 - AppSizes.sidebarCollapsed);
    await tester.pumpWidget(
      _wrap(
        controller: _twoLoans(
          summary: testMortgageSummary(
            incomeSource: IncomeSource.ledger,
            monthlyIncomeMinor: 285000,
            debtRatioBps: 5285,
            overLimit: true,
          ),
        ),
        locale: const Locale('en'),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Monthly charge'), findsOneWidget);
    expect(find.text('Above the reference'), findsOneWidget);
    final meter = tester.widget<RepereMeter>(
      find.byKey(const Key('ratioGauge')),
    );
    expect(meter.markLabel, 'HCSF reference 35%');
  });

  testWidgets('no loans shows the empty state without summary or chart', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_wrap(controller: FakeMortgagesController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mortgagesEmptyState')), findsOneWidget);
    expect(find.text('Aucun crédit enregistré'), findsOneWidget);
    expect(
      find.text(
        'Ajoutez un emprunt pour suivre son coût, son échéancier et votre '
        'taux d’endettement.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mortgagesEmptyCta')), findsOneWidget);
    expect(find.byKey(const Key('mortgagesSummaryLine')), findsNothing);
    expect(find.byKey(const Key('trajectorySection')), findsNothing);
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
