import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/recurring/application/subscriptions_controller.dart';
import 'package:bastide/features/recurring/domain/recurring_series.dart';
import 'package:bastide/features/recurring/presentation/series_form_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
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
}) {
  return ProviderScope(
    overrides: [
      subscriptionsControllerProvider.overrideWith(() => controller),
      subscriptionAccountsProvider.overrideWith((ref) => const [_account]),
      subscriptionCategoriesProvider.overrideWith((ref) => []),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SeriesFormModal(
          initial: initial ?? testSeries(id: 's1', label: 'Netflix'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('saving stores the amount as a signed outflow', (tester) async {
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

    final (seriesId, label, amount) = controller.updateCalls.single;
    expect(seriesId, 's1');
    expect(label, 'Basic-Fit');
    expect(amount, -2999);
  });

  testWidgets('the cadence select offers Irrégulier', (tester) async {
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
  });

  testWidgets('a name and a positive amount are both required', (tester) async {
    final controller = FakeSubscriptionsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('seriesFormName')), ' ');
    await tester.enterText(find.byKey(const Key('seriesFormAmount')), '0');
    await tester.tap(find.byKey(const Key('seriesFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Donnez un nom à ce paiement.'), findsOneWidget);
    expect(find.text('Saisissez un montant supérieur à zéro.'), findsOneWidget);
    expect(controller.updateCalls, isEmpty);
  });

  testWidgets('a refused save is stated inline and leaves the form open', (
    tester,
  ) async {
    final controller = FakeSubscriptionsController()
      ..errorOnUpdate = const ApiFailure(
        code: 'RECURRING_SERIES_NOT_FOUND',
        message: 'gone',
      );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seriesFormSubmit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
    expect(find.byKey(const Key('seriesFormName')), findsOneWidget);
  });

  testWidgets('the account is stated rather than offered for a move', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le paiement récurrent'), findsOneWidget);
    expect(find.text('BNP — Compte courant'), findsOneWidget);
    // The amount round-trips unsigned, in the locale's own decimal form.
    expect(find.text('15,49'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('the fields read Nom, Compte, Montant and Cadence, Catégorie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
    await tester.pumpAndSettle();

    final labels = ['Nom', 'Compte', 'Montant', 'Catégorie'];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: labels[i]);
    }
    // Montant and Cadence side by side, aligned on their inputs.
    final amount = tester.getTopLeft(find.byKey(const Key('seriesFormAmount')));
    final cadence = tester.getTopLeft(
      find.byKey(const Key('seriesFormCadence')),
    );
    expect(cadence.dy, amount.dy);
    expect(cadence.dx, greaterThan(amount.dx));
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('an edited form asks before dropping the input', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeSubscriptionsController()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('seriesFormName')), 'Gym');
    await tester.pump();
    await tester.tap(find.byKey(const Key('seriesFormCancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
  });
}
