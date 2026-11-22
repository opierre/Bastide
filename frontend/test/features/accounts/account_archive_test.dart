import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/presentation/account_archive.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';

final _account = Account(
  id: 'acc-1',
  name: 'Compte joint',
  type: AccountType.checking,
  institution: 'Banque Exemple',
  currency: 'EUR',
  openingBalanceMinor: 125000,
  balanceMinor: 125000,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _wrap(FakeAccountsController controller, List<bool> results) =>
    ProviderScope(
      overrides: [accountsControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => results.add(
                await confirmArchiveAccount(context, ref, _account),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a v6 confirmation: 420, title, lead, no body, ink « Archiver »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FakeAccountsController(), []));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final modal = tester.widget<AppModal>(find.byType(AppModal));
    expect(modal.width, AppModalSizes.w420);
    expect(modal.kind, AppModalKind.confirmation);
    expect(modal.child, isNull);
    expect(find.text('Archiver ce compte ?'), findsOneWidget);
    expect(
      find.text(
        'Vous pourrez toujours consulter son historique, mais il n’apparaîtra '
        'plus dans votre liste de comptes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Archiver'), findsOneWidget);
  });

  testWidgets('« Archiver » archives the account and resolves true', (
    tester,
  ) async {
    final controller = FakeAccountsController(initialAccounts: [_account]);
    final results = <bool>[];
    await tester.pumpWidget(_wrap(controller, results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountArchiveConfirmButton')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, ['acc-1']);
    expect(results, [true]);
    expect(find.byType(AppModal), findsNothing);
  });

  testWidgets('« Annuler » archives nothing and resolves false', (
    tester,
  ) async {
    final controller = FakeAccountsController(initialAccounts: [_account]);
    final results = <bool>[];
    await tester.pumpWidget(_wrap(controller, results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountArchiveCancelButton')));
    await tester.pumpAndSettle();

    expect(controller.archiveCalls, isEmpty);
    expect(results, [false]);
  });

  testWidgets('a failed archive stays open with the error', (tester) async {
    final controller = FakeAccountsController(initialAccounts: [_account])
      ..errorOnArchive = Exception('boom');
    final results = <bool>[];
    await tester.pumpWidget(_wrap(controller, results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountArchiveConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AppModal), findsOneWidget);
    expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
    expect(results, isEmpty);
  });
}
