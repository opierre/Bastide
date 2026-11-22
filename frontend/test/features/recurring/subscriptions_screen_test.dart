import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/amount_text.dart';
import 'package:bastide/core/widgets/app_button.dart';
import 'package:bastide/core/widgets/app_table.dart';
import 'package:bastide/core/widgets/inline_banner.dart';
import 'package:bastide/core/widgets/state_views.dart';
import 'package:bastide/core/widgets/status_text.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/domain/recurring_summary.dart';
import 'package:bastide/features/recurring/presentation/subscriptions_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/recurring_fixtures.dart';

/// The panel's own money formatting, so the expectations can't drift from the
/// locale's separators (French uses a narrow no-break space before « € »).
String _money(int amountMinor, {String locale = 'fr'}) =>
    formatAmount(amountMinor: amountMinor, currency: 'EUR', locale: locale);

Widget _wrap({
  required FakeSubscriptionsController controller,
  Locale locale = const Locale('fr'),
  List<AppCategory> categories = const [],
  List<SeriesAccount> accounts = const [],
  bool withTopBar = false,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      subscriptionsControllerProvider.overrideWith(() => controller),
      subscriptionCategoriesProvider.overrideWith((ref) => categories),
      subscriptionAccountsProvider.overrideWith((ref) => accounts),
    ],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: withTopBar
            ? AppBar(actions: const [SubscriptionsTopBarActions()])
            : null,
        body: const SubscriptionsScreen(),
      ),
    ),
  );
}

/// The panel is drawn for the 1440×900 desktop frame the design targets — the
/// table runs to a 230 px Statut column and needs the width it was drawn at.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'a healthy row renders cadence, a neutral amount and the next date',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeSubscriptionsController(
            initialSeries: [testSeries()],
            summary: testSummary(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mensuel'), findsOneWidget);
      expect(find.text('15\u00A0mai'), findsOneWidget);

      // Unsigned and in the primary ink: an expected charge is not a ledger
      // entry, so the money rule's red would state something false about it.
      final amount = tester.widget<AmountText>(
        find.byKey(const Key('seriesAmount-s1')),
      );
      expect(amount.amountMinor, 1549);
      expect(amount.colorize, isFalse);
      expect(find.text(_money(1549)), findsOneWidget);

      // Nothing is wrong with this subscription, so the État cell is empty.
      expect(find.byType(StatusText), findsNothing);
    },
  );

  testWidgets('a price increase and a missed charge read as warning status', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [
            testSeries(),
            testSeries(
              id: 's2',
              label: 'Basic-Fit',
              expectedAmountMinor: -2999,
            ),
          ],
          summary: testSummary(
            activeCount: 2,
            priceIncreases: [
              PriceIncrease(
                seriesId: 's1',
                deltaMinor: -200,
                changedAt: DateTime(2026, 4, 15),
              ),
            ],
            missed: [
              MissedCharge(
                seriesId: 's2',
                expectedOn: DateTime(2026, 5, 5),
                daysLate: 9,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pills = tester
        .widgetList<StatusText>(find.byType(StatusText))
        .toList();
    expect(pills, hasLength(2));
    expect(pills.every((pill) => pill.tone == StatusTone.warning), isTrue);
    expect(
      find.text('Hausse : ${_money(1349)} → ${_money(1549)}'),
      findsOneWidget,
    );
    expect(
      find.text('Prélèvement manquant depuis 9\u00A0jours'),
      findsOneWidget,
    );

    // The overdue row states what was expected instead of printing a past date
    // under a "next charge" header.
    expect(find.byKey(const Key('seriesNextExpected-s2')), findsOneWidget);
    expect(find.text('attendu le 5\u00A0mai'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('seriesNextExpected-s2')))
          .style
          ?.color,
      AppTheme.dark.extension<AppColors>()!.warning,
    );
  });

  testWidgets(
    'a cancelled row dims, drops its next date, and says when it ended',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeSubscriptionsController(
            initialSeries: [
              testSeries(label: 'Canal+', status: SeriesStatus.cancelled),
            ],
            summary: testSummary(activeCount: 0, cancelledCount: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppTableRow>(find.byKey(const Key('seriesRow-s1')))
            .dimmed,
        isTrue,
      );
      // Settled, not something to look at: no status icon.
      expect(find.byType(StatusText), findsNothing);
      expect(
        find.text('Résilié, dernier prélèvement le 15\u00A0avril 2026'),
        findsOneWidget,
      );
      expect(find.text('15\u00A0mai'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('seriesRow-s1')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the kebab offers only the transitions the current status allows',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeSubscriptionsController(
            initialSeries: [testSeries(status: SeriesStatus.confirmed)],
            summary: testSummary(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('seriesMenu-s1')));
      await tester.pumpAndSettle();

      // confirmed → cancelled | dismissed. Confirming again is not a transition
      // the lifecycle has, so the menu must not offer it.
      expect(find.byKey(const Key('seriesActionCancel-s1')), findsOneWidget);
      expect(find.byKey(const Key('seriesActionDismiss-s1')), findsOneWidget);
      expect(find.byKey(const Key('seriesActionConfirm-s1')), findsNothing);
      expect(find.byKey(const Key('seriesActionEdit-s1')), findsOneWidget);
    },
  );

  testWidgets('a lifecycle action patches the series and refreshes the row', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller = FakeSubscriptionsController(
      initialSeries: [testSeries()],
      summary: testSummary(),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesMenu-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seriesActionConfirm-s1')));
    await tester.pumpAndSettle();

    expect(controller.statusCalls, [('s1', SeriesStatus.confirmed)]);
  });

  group('archive', () {
    testWidgets('an archived series leaves the list and can be restored', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final controller = FakeSubscriptionsController(
        initialSeries: [
          testSeries(),
          testSeries(id: 's2', label: 'Gymfit Club'),
        ],
        summary: testSummary(activeCount: 2),
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      // Nothing archived yet, so no link to reveal an empty list.
      expect(
        find.byKey(const Key('subscriptionsArchivedToggle')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('seriesMenu-s2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('seriesActionArchive-s2')));
      await tester.pumpAndSettle();

      expect(controller.archiveCalls, ['s2']);
      expect(find.byKey(const Key('seriesRow-s2')), findsNothing);
      expect(find.text('Afficher les paiements archivés (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('subscriptionsArchivedToggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('subscriptionsArchivedSection')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('seriesRow-s2')), findsOneWidget);
      expect(find.text('Masquer les paiements archivés (1)'), findsOneWidget);

      // An archived row offers only « Désarchiver ».
      await tester.tap(find.byKey(const Key('seriesMenu-s2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('seriesActionArchive-s2')), findsNothing);
      expect(find.byKey(const Key('seriesActionEdit-s2')), findsNothing);
      expect(find.text('Désarchiver'), findsOneWidget);
      await tester.tap(find.byKey(const Key('seriesActionUnarchive-s2')));
      await tester.pumpAndSettle();

      expect(controller.unarchiveCalls, ['s2']);
      expect(find.byKey(const Key('seriesRow-s2')), findsOneWidget);
      expect(
        find.byKey(const Key('subscriptionsArchivedSection')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('subscriptionsArchivedToggle')),
        findsNothing,
      );
    });

    testWidgets('a live row offers « Archiver » beside the lifecycle', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeSubscriptionsController(
            initialSeries: [testSeries()],
            summary: testSummary(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('seriesMenu-s1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seriesActionConfirm-s1')), findsOneWidget);
      expect(find.byKey(const Key('seriesActionArchive-s1')), findsOneWidget);
      expect(find.text('Archiver'), findsOneWidget);
    });

    testWidgets(
      'only archived series still draw the panel, not the empty state',
      (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            controller: FakeSubscriptionsController(
              initialArchived: [testSeries(isArchived: true)],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('subscriptionsEmptyState')), findsNothing);
        expect(
          find.byKey(const Key('subscriptionsArchivedToggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets('reads in English', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          locale: const Locale('en'),
          controller: FakeSubscriptionsController(
            initialSeries: [testSeries()],
            initialArchived: [
              testSeries(id: 's2', label: 'Gymfit Club', isArchived: true),
            ],
            summary: testSummary(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show archived payments (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('subscriptionsArchivedToggle')));
      await tester.pumpAndSettle();
      expect(find.text('Hide archived payments (1)'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      await tester.tap(find.byKey(const Key('seriesMenu-s1')));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('seriesMenu-s2')));
      await tester.pumpAndSettle();
      expect(find.text('Unarchive'), findsOneWidget);
    });
  });

  testWidgets('a refused transition shows a message and keeps the list', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final controller =
        FakeSubscriptionsController(
            initialSeries: [testSeries()],
            summary: testSummary(),
          )
          ..errorOnStatusChange = const ApiFailure(
            code: 'RECURRING_INVALID_TRANSITION',
            message: 'nope',
          );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesMenu-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seriesActionConfirm-s1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsActionError')), findsOneWidget);
    expect(
      find.text("Ce changement de statut n’est pas possible pour ce paiement."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seriesRow-s1')), findsOneWidget);
  });

  testWidgets('the summary line reads straight from the summary payload', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries()],
          summary: testSummary(
            monthlyTotalMinor: -21208,
            activeCount: 7,
            cancelledCount: 1,
            cadenceCounts: {
              Cadence.weekly: 0,
              Cadence.monthly: 5,
              Cadence.quarterly: 1,
              Cadence.yearly: 1,
              Cadence.irregular: 0,
            },
            nextCharge: NextCharge(
              seriesId: 's1',
              label: 'Netflix',
              amountMinor: -1549,
              dueOn: DateTime.now().add(const Duration(days: 1)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Charge mensuelle'), findsOneWidget);
    expect(find.text(_money(21208)), findsOneWidget);
    expect(
      find.text('Trimestriels et annuels ramenés au mois'),
      findsOneWidget,
    );
    expect(find.text('Actifs'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5 mensuels · 1 trimestriel · 1 annuel'), findsOneWidget);
    expect(find.text('Prochain prélèvement'), findsOneWidget);
    expect(find.text('Netflix, demain'), findsOneWidget);
    // Nothing to look at, so « À regarder » is hidden.
    expect(find.byKey(const Key('subscriptionsWatch')), findsNothing);
    expect(find.text('À regarder'), findsNothing);
  });

  testWidgets('« À regarder » counts the rises and the missed charges', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [
            testSeries(),
            testSeries(id: 's2', label: 'Basic-Fit'),
          ],
          summary: testSummary(
            activeCount: 2,
            priceIncreases: [
              PriceIncrease(
                seriesId: 's1',
                deltaMinor: -200,
                changedAt: DateTime(2026, 4, 15),
              ),
            ],
            missed: [
              MissedCharge(
                seriesId: 's2',
                expectedOn: DateTime(2026, 5, 5),
                daysLate: 9,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('À regarder'), findsOneWidget);
    final count = tester.widget<Text>(
      find.byKey(const Key('subscriptionsWatchCount')),
    );
    expect(count.data, '2');
    expect(count.style?.color, AppTheme.dark.extension<AppColors>()!.warning);
    expect(find.text('1 hausse · 1 prélèvement manquant'), findsOneWidget);
  });

  testWidgets(
    'the empty state explains the three-repeat rule and offers detection',
    (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subscriptionsEmptyState')), findsOneWidget);
      expect(find.text('Aucun paiement récurrent détecté'), findsOneWidget);
      expect(
        find.textContaining('un prélèvement s’est répété trois fois'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('subscriptionsEmptyDetectButton')),
        findsOneWidget,
      );
      expect(find.text('Détecter'), findsOneWidget);
      expect(find.text('Aller aux imports'), findsNothing);
    },
  );

  testWidgets(
    'the empty state button runs the top bar detection, toast included',
    (tester) async {
      _useDesktopSurface(tester);
      final controller = FakeSubscriptionsController()
        ..detectGate = Completer<void>();
      await tester.pumpWidget(_wrap(controller: controller, withTopBar: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subscriptionsEmptyDetectButton')));
      await tester.pump();

      expect(controller.detectCalls, 1);
      // One running state for both buttons: the top bar's spins too.
      expect(find.byKey(const Key('appButtonSpinner')), findsNWidgets(2));
      final topBar = tester.widget<AppButton>(
        find.byKey(const Key('subscriptionsDetectButton')),
      );
      expect(topBar.isLoading, isTrue);

      controller.detectGate!.complete();
      await tester.pump();
      await tester.pump();

      expect(
        find.text('2 nouveaux paiements récurrents détectés'),
        findsOneWidget,
      );
      expect(find.text('1 série existante mise à jour'), findsOneWidget);
      expect(find.byKey(const Key('appButtonSpinner')), findsNothing);

      // Let the toast withdraw so no timer outlives the test.
      await tester.pump(const Duration(seconds: 7));
    },
  );

  testWidgets('a failed load offers a retry rather than an empty panel', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          loadError: const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionsErrorText')), findsOneWidget);
    expect(find.byKey(const Key('subscriptionsRetryButton')), findsOneWidget);
  });

  testWidgets('the panel renders in English with the strings frame ⑤ pins', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        locale: const Locale('en'),
        controller: FakeSubscriptionsController(
          initialSeries: [
            testSeries(),
            testSeries(
              id: 's2',
              label: 'Basic-Fit',
              expectedAmountMinor: -2999,
            ),
            testSeries(
              id: 's3',
              label: 'Canal+',
              status: SeriesStatus.cancelled,
            ),
          ],
          summary: testSummary(
            activeCount: 2,
            cancelledCount: 1,
            missed: [
              MissedCharge(
                seriesId: 's2',
                expectedOn: DateTime(2026, 5, 5),
                daysLate: 9,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly'), findsNWidgets(3));
    expect(find.text('Missed charge for 9\u00A0days'), findsOneWidget);
    expect(find.textContaining('Cancelled, last charge on'), findsOneWidget);
    // Netflix and the cancelled Canal+ share a price in this fixture.
    expect(find.text(_money(1549, locale: 'en')), findsNWidgets(2));
    expect(find.text('Monthly cost'), findsOneWidget);
    expect(find.text('Worth a look'), findsOneWidget);
    expect(find.text('1 missed charge'), findsOneWidget);
  });

  testWidgets('a row wears its category label', (tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(
          initialSeries: [testSeries(categoryId: 'leisure')],
          summary: testSummary(),
        ),
        categories: [testCategory(id: 'leisure', name: 'category.leisure')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loisirs'), findsOneWidget);
  });

  testWidgets('a row opens its series under the « Abonnements » crumb', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final series = testSeries();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsControllerProvider.overrideWith(
            () => FakeSubscriptionsController(
              initialSeries: [series],
              summary: testSummary(),
            ),
          ),
          subscriptionCategoriesProvider.overrideWith((ref) => []),
          subscriptionAccountsProvider.overrideWith((ref) => []),
          seriesDetailProvider.overrideWith(
            (ref, id) => SeriesDetail(series: series, occurrences: const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(
              title: const SubscriptionsTitle(),
              actions: const [SubscriptionsTopBarActions()],
            ),
            body: const SubscriptionsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('titleBarCrumb')), findsNothing);
    expect(find.byKey(const Key('subscriptionsDetectButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('seriesRow-s1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seriesDetail')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('titleBarCrumb'))).data,
      'Abonnements',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('titleBarTitle'))).data,
      'Netflix',
    );
    // The detail's own controls replace « Détecter ».
    expect(find.byKey(const Key('subscriptionsDetectButton')), findsNothing);
    expect(find.byKey(const Key('seriesDetailEdit')), findsOneWidget);
    expect(find.byKey(const Key('seriesDetailMore')), findsOneWidget);

    await tester.tap(find.byKey(const Key('titleBarCrumb')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seriesDetail')), findsNothing);
    expect(find.byKey(const Key('seriesRow-s1')), findsOneWidget);
  });

  group('layout', () {
    FakeSubscriptionsController populated() => FakeSubscriptionsController(
      initialSeries: [
        testSeries(),
        testSeries(
          id: 's2',
          label: 'Salle de sport du quartier',
          expectedAmountMinor: -2999,
        ),
        testSeries(
          id: 's3',
          label: 'Presse en ligne',
          cadence: Cadence.yearly,
          expectedAmountMinor: -18744,
        ),
        testSeries(id: 's4', label: 'Canal TV', status: SeriesStatus.cancelled),
      ],
      summary: testSummary(
        activeCount: 3,
        cancelledCount: 1,
        nextCharge: NextCharge(
          seriesId: 's1',
          label: 'Netflix',
          amountMinor: -1549,
          dueOn: DateTime(2026, 5, 15),
        ),
        priceIncreases: [
          PriceIncrease(
            seriesId: 's1',
            deltaMinor: -200,
            changedAt: DateTime(2026, 4, 15),
          ),
        ],
        missed: [
          MissedCharge(
            seriesId: 's2',
            expectedOn: DateTime(2026, 5, 5),
            daysLate: 9,
          ),
        ],
      ),
      mergeSuggestions: [
        MergeSuggestion(
          target: testSeries(id: 's5', label: 'STREAMCO - STREAMCO TV'),
          source: testSeries(id: 's6', label: 'STREAMCO'),
        ),
      ],
    );

    // The content region at 1440 × 900: beside the 224 px sidebar, and
    // beside the 56 px collapsed one.
    for (final (name, width) in [
      ('sidebar expanded', 1440.0 - 224),
      ('sidebar collapsed', 1440.0 - 56),
    ]) {
      for (final (themeName, theme) in [
        ('dark', AppTheme.dark),
        ('light', AppTheme.light),
      ]) {
        for (final locale in const [Locale('fr'), Locale('en')]) {
          testWidgets('renders without overflow, $name, $themeName, '
              '${locale.languageCode}', (tester) async {
            tester.view.physicalSize = Size(width, 900 - 48);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _wrap(controller: populated(), theme: theme, locale: locale),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('subscriptionsSummaryLine')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('subscriptionsMergeBanner')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('seriesRow-s4')), findsOneWidget);
          });
        }
      }
    }

    testWidgets('loading draws the summary and row silhouettes', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final gate = Completer<void>();
      await tester.pumpWidget(
        _wrap(controller: _SlowSubscriptionsController(gate.future)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('subscriptionsLoadingIndicator')),
        findsOneWidget,
      );
      expect(find.byType(SkeletonBlock), findsNWidgets(9));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('merge suggestion', () {
    MergeSuggestion suggestion() => MergeSuggestion(
      target: testSeries(id: 's2', label: 'STREAMCO - STREAMCO TV'),
      source: testSeries(label: 'STREAMCO'),
    );

    testWidgets('names both labels and merges on « Fusionner »', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final pair = suggestion();
      final controller = FakeSubscriptionsController(
        initialSeries: [pair.source, pair.target],
        summary: testSummary(),
        mergeSuggestions: [pair],
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('subscriptionsMergeText')))
            .data,
        '« STREAMCO » et « STREAMCO - STREAMCO TV » semblent être le même '
        'abonnement, renommé par la banque.',
      );
      // Informational, never a warning: the neutral banner with `merge`.
      final banner = tester.widget<InlineBanner>(
        find.byKey(const Key('subscriptionsMergeBanner')),
      );
      expect(banner.icon, LucideIcons300.merge);
      expect(banner.tone, BannerTone.info);

      await tester.tap(find.byKey(const Key('subscriptionsMergeAction')));
      await tester.pumpAndSettle();

      expect(controller.mergeCalls, [pair]);
      expect(find.byKey(const Key('subscriptionsMergeBanner')), findsNothing);
      expect(find.text('Abonnements fusionnés'), findsOneWidget);
      // Let the toast withdraw before the test tears down.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('« Ce sont deux abonnements » keeps the pair apart', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      final pair = suggestion();
      final controller = FakeSubscriptionsController(
        initialSeries: [pair.source, pair.target],
        summary: testSummary(),
        mergeSuggestions: [pair],
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subscriptionsMergeKeepApart')));
      await tester.pumpAndSettle();

      expect(controller.keepApartCalls, [pair]);
      expect(controller.mergeCalls, isEmpty);
      expect(find.byKey(const Key('subscriptionsMergeBanner')), findsNothing);
    });

    testWidgets('reads in English', (tester) async {
      _useDesktopSurface(tester);
      final pair = suggestion();
      await tester.pumpWidget(
        _wrap(
          locale: const Locale('en'),
          controller: FakeSubscriptionsController(
            initialSeries: [pair.source, pair.target],
            summary: testSummary(),
            mergeSuggestions: [pair],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Merge'), findsOneWidget);
      expect(find.text("They’re different"), findsOneWidget);
    });

    group('several suggestions', () {
      final streamco = MergeSuggestion(
        target: testSeries(id: 's2', label: 'STREAMCO - STREAMCO TV'),
        source: testSeries(label: 'STREAMCO'),
      );
      final gym = MergeSuggestion(
        target: testSeries(id: 's4', label: 'GYM CLUB PARIS 11'),
        source: testSeries(id: 's3', label: 'GYM CLUB PARIS'),
      );

      FakeSubscriptionsController controllerWith(List<MergeSuggestion> pairs) =>
          FakeSubscriptionsController(
            initialSeries: [
              for (final p in pairs) ...[p.source, p.target],
            ],
            summary: testSummary(),
            mergeSuggestions: pairs,
          );

      Finder bannerOf(MergeSuggestion pair) =>
          find.byKey(ValueKey('merge-${pair.target.id}-${pair.source.id}'));

      testWidgets('lists every pair under a count', (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(controller: controllerWith([streamco, gym])),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 suggestions de fusion'), findsOneWidget);
        expect(
          find.byKey(const Key('subscriptionsMergeBanner')),
          findsNWidgets(2),
        );
        expect(bannerOf(streamco), findsOneWidget);
        expect(bannerOf(gym), findsOneWidget);
      });

      testWidgets('merges the pair it was asked about, and keeps the rest', (
        tester,
      ) async {
        _useDesktopSurface(tester);
        final controller = controllerWith([streamco, gym]);
        await tester.pumpWidget(_wrap(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: bannerOf(gym),
            matching: find.byKey(const Key('subscriptionsMergeAction')),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.mergeCalls, [gym]);
        expect(bannerOf(gym), findsNothing);
        expect(bannerOf(streamco), findsOneWidget);
        // Down to one, it reads as the plain banner again.
        expect(find.byKey(const Key('subscriptionsMergePanel')), findsNothing);
        await tester.pump(const Duration(seconds: 7));
      });

      testWidgets('keeps one pair apart without touching the other', (
        tester,
      ) async {
        _useDesktopSurface(tester);
        final controller = controllerWith([streamco, gym]);
        await tester.pumpWidget(_wrap(controller: controller));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: bannerOf(streamco),
            matching: find.byKey(const Key('subscriptionsMergeKeepApart')),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.keepApartCalls, [streamco]);
        expect(controller.mergeCalls, isEmpty);
        expect(bannerOf(streamco), findsNothing);
        expect(bannerOf(gym), findsOneWidget);
      });

      testWidgets('folds away and back under its header', (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(controller: controllerWith([streamco, gym])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('subscriptionsMergeToggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('subscriptionsMergeBanner')), findsNothing);
        expect(find.text('2 suggestions de fusion'), findsOneWidget);

        await tester.tap(find.byKey(const Key('subscriptionsMergeToggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('subscriptionsMergeBanner')),
          findsNWidgets(2),
        );
      });

      testWidgets('a long list scrolls instead of pushing the table away', (
        tester,
      ) async {
        _useDesktopSurface(tester);
        final pairs = [
          for (var i = 0; i < 6; i++)
            MergeSuggestion(
              target: testSeries(id: 't$i', label: 'MUSICO $i PLUS'),
              source: testSeries(id: 'o$i', label: 'MUSICO $i'),
            ),
        ];
        await tester.pumpWidget(_wrap(controller: controllerWith(pairs)));
        await tester.pumpAndSettle();

        expect(find.text('6 suggestions de fusion'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(
          bannerOf(pairs.last),
          find.byKey(const Key('subscriptionsMergeList')),
          const Offset(0, -60),
        );
        expect(bannerOf(pairs.last), findsOneWidget);
      });

      testWidgets('reads in English', (tester) async {
        _useDesktopSurface(tester);
        await tester.pumpWidget(
          _wrap(
            locale: const Locale('en'),
            controller: controllerWith([streamco, gym]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 merge suggestions'), findsOneWidget);
        expect(find.text('Merge'), findsNWidgets(2));
      });
    });

    testWidgets('no suggestion, no banner', (tester) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(
        _wrap(
          controller: FakeSubscriptionsController(
            initialSeries: [testSeries()],
            summary: testSummary(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subscriptionsMergeBanner')), findsNothing);
    });
  });

  group('sorting', () {
    FakeSubscriptionsController controller() => FakeSubscriptionsController(
      initialSeries: [
        testSeries(
          id: 's1',
          label: 'Gym',
          expectedAmountMinor: -2999,
          nextExpectedDate: DateTime(2026, 5, 20),
        ),
        testSeries(
          id: 's2',
          label: 'Assurance',
          expectedAmountMinor: -4500,
          status: SeriesStatus.cancelled,
        ),
        testSeries(
          id: 's3',
          label: 'Musique',
          expectedAmountMinor: -1099,
          nextExpectedDate: DateTime(2026, 5, 16),
        ),
      ],
      summary: testSummary(activeCount: 2),
    );

    Finder header(String label) => find.descendant(
      of: find.byKey(const Key('seriesTableHeader')),
      matching: find.text(label),
    );

    IconData? sortIcon(WidgetTester tester) =>
        tester.widget<Icon>(find.byKey(const Key('appTableSortIcon'))).icon;

    /// The row ids top to bottom, as drawn.
    List<String> drawnOrder(WidgetTester tester) {
      double top(String id) =>
          tester.getTopLeft(find.byKey(Key('seriesRow-$id'))).dy;
      return ['s1', 's2', 's3']..sort((a, b) => top(a).compareTo(top(b)));
    }

    testWidgets('clicking a header sorts on it, clicking again reverses', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: controller()));
      await tester.pumpAndSettle();

      // Opens on the soonest charge, the cancelled series last.
      expect(drawnOrder(tester), ['s3', 's1', 's2']);
      expect(sortIcon(tester), LucideIcons300.chevronUp);

      await tester.tap(header('Montant'));
      await tester.pumpAndSettle();
      expect(drawnOrder(tester), ['s1', 's3', 's2']);
      expect(sortIcon(tester), LucideIcons300.chevronDown);

      await tester.tap(header('Montant'));
      await tester.pumpAndSettle();
      expect(drawnOrder(tester), ['s3', 's1', 's2']);
      expect(sortIcon(tester), LucideIcons300.chevronUp);

      await tester.tap(header('Abonnement'));
      await tester.pumpAndSettle();
      expect(drawnOrder(tester), ['s1', 's3', 's2']);
    });

    testWidgets('next charge flips, and the cancelled stays last', (
      tester,
    ) async {
      _useDesktopSurface(tester);
      await tester.pumpWidget(_wrap(controller: controller()));
      await tester.pumpAndSettle();

      await tester.tap(header('Prochain'));
      await tester.pumpAndSettle();
      expect(drawnOrder(tester), ['s1', 's3', 's2']);

      await tester.tap(header('Prochain'));
      await tester.pumpAndSettle();
      expect(drawnOrder(tester), ['s3', 's1', 's2']);
    });
  });
}

/// Holds the first load until [gate] completes, so the loading state shows.
class _SlowSubscriptionsController extends FakeSubscriptionsController {
  _SlowSubscriptionsController(this.gate);

  final Future<void> gate;

  @override
  Future<SubscriptionsState> build() async {
    await gate;
    return super.build();
  }
}
