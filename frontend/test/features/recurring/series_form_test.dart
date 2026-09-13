import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/recurring/application/subscriptions_controller.dart';
import 'package:finstride/features/recurring/domain/recurring_series.dart';
import 'package:finstride/features/recurring/presentation/series_form_modal.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurring_fixtures.dart';

const _account = SeriesAccount(
  id: 'a1',
  name: 'Compte courant',
  institution: 'BNP',
  currency: 'EUR',
);

Widget _wrap({
  required FakeSubscriptionsController controller,
  RecurringSeries? initial,
  List<SeriesAccount> accounts = const [_account],
}) {
  return ProviderScope(
    overrides: [
      subscriptionsControllerProvider.overrideWith(() => controller),
      subscriptionAccountsProvider.overrideWith((ref) => accounts),
      subscriptionCategoriesProvider.overrideWith((ref) => []),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SeriesFormModal(initial: initial)),
    ),
  );
}

void main() {
  testWidgets('a declared subscription is stored as a signed outflow', (
    tester,
  ) async {
    final controller = FakeSubscriptionsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('seriesFormName')),
      'Basic-Fit',
    );
    // Typed the way the user reads a price — the sign is this form's own
    // statement that a subscription leaves the account.
    await tester.enterText(find.byKey(const Key('seriesFormAmount')), '29,99');
    await tester.tap(find.byKey(const Key('seriesFormSubmit')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, hasLength(1));
    expect(controller.createCalls.single.expectedAmountMinor, -2999);
    expect(controller.createCalls.single.label, 'Basic-Fit');
    expect(controller.createCalls.single.accountId, 'a1');
    expect(controller.createCalls.single.cadence, Cadence.monthly);
  });

  testWidgets(
    'the cadence select offers Irrégulier — the only place it can be chosen',
    (tester) async {
      await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('seriesFormCadence')));
      await tester.pumpAndSettle();

      for (final label in [
        'Hebdomadaire',
        'Mensuel',
        'Trimestriel',
        'Annuel',
        'Irrégulier',
      ]) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '$label should be offered',
        );
      }
    },
  );

  testWidgets('a name and a positive amount are both required', (tester) async {
    final controller = FakeSubscriptionsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('seriesFormAmount')), '0');
    await tester.tap(find.byKey(const Key('seriesFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Donnez un nom à ce paiement.'), findsOneWidget);
    expect(find.text('Saisissez un montant supérieur à zéro.'), findsOneWidget);
    expect(controller.createCalls, isEmpty);
  });

  testWidgets('a refused create is stated inline and leaves the form open', (
    tester,
  ) async {
    final controller = FakeSubscriptionsController()
      ..errorOnCreate = const ApiFailure(
        code: 'RECURRING_SERIES_EXISTS',
        message: 'taken',
      );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('seriesFormName')), 'Netflix');
    await tester.enterText(find.byKey(const Key('seriesFormAmount')), '15,49');
    await tester.tap(find.byKey(const Key('seriesFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seriesFormError')), findsOneWidget);
    expect(
      find.text('Ce compte suit déjà un paiement récurrent sous ce nom.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seriesFormName')), findsOneWidget);
  });

  testWidgets('editing states the account rather than offering to move it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeSubscriptionsController(),
        initial: testSeries(label: 'Netflix'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier le paiement récurrent'), findsOneWidget);
    expect(find.byKey(const Key('seriesFormAccount')), findsNothing);
    expect(find.text('BNP — Compte courant'), findsOneWidget);
    // The amount round-trips unsigned, in the locale's own decimal form.
    expect(find.text('15,49'), findsOneWidget);
  });
}
