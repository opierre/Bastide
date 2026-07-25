import 'package:finstride/core/session/current_user_provider.dart';
import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:finstride/features/accounts/presentation/account_form.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_accounts_controller.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

Widget _wrap({required FakeAccountsController controller, Account? initial}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(() => controller),
      currentUserProvider.overrideWithValue(_user),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: AccountForm(initial: initial))),
    ),
  );
}

void main() {
  testWidgets('submitting the create form calls the controller with the chosen values', (tester) async {
    final controller = FakeAccountsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('accountNameField')), 'Compte courant');
    await tester.enterText(find.byKey(const Key('accountInstitutionField')), 'BNP Paribas');
    await tester.enterText(find.byKey(const Key('accountOpeningBalanceField')), '1234,56');

    await tester.tap(find.byKey(const Key('accountTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Épargne').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, hasLength(1));
    final call = controller.createCalls.single;
    expect(call.name, 'Compte courant');
    expect(call.institution, 'BNP Paribas');
    expect(call.type, AccountType.savings);
    expect(call.openingBalanceMinor, 123456);
  });

  testWidgets('the opening balance field is disabled when editing', (tester) async {
    final initial = Account(
      id: 'a1',
      name: 'Compte courant',
      type: AccountType.checking,
      institution: 'BNP Paribas',
      currency: 'EUR',
      openingBalanceMinor: 10000,
      balanceMinor: 15000,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final controller = FakeAccountsController();
    await tester.pumpWidget(_wrap(controller: controller, initial: initial));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byKey(const Key('accountOpeningBalanceField')));
    expect(field.enabled, isFalse);

    await tester.enterText(find.byKey(const Key('accountNameField')), 'Compte courant modifié');
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.updateCalls, hasLength(1));
  });
}
