import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/widgets/institution_avatar.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/presentation/account_form.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../support/fake_accounts_controller.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'ada@example.com',
  displayName: 'Ada',
  locale: 'fr',
  currency: 'EUR',
);

Widget _wrap({
  required FakeAccountsController controller,
  Account? initial,
  AccountPrefill? prefill,
}) {
  return ProviderScope(
    overrides: [
      accountsControllerProvider.overrideWith(() => controller),
      currentUserProvider.overrideWithValue(_user),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: AccountForm(initial: initial, prefill: prefill),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'submitting the create form calls the controller with the chosen values',
    (tester) async {
      final controller = FakeAccountsController();
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accountNameField')),
        'Compte courant',
      );
      await tester.enterText(
        find.byKey(const Key('accountInstitutionField')),
        'BNP Paribas',
      );
      await tester.enterText(
        find.byKey(const Key('accountOpeningBalanceField')),
        '1234,56',
      );

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
    },
  );

  testWidgets(
    'a prefill seeds the create form, and what it proposes stays editable',
    (tester) async {
      final controller = FakeAccountsController();
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          prefill: const AccountPrefill(
            name: 'Compte courant ••4567',
            institution: 'BOURSORAMA BANQUE',
            type: AccountType.savings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountFormPrefillNote')), findsOneWidget);
      expect(find.text('Compte courant ••4567'), findsOneWidget);
      expect(find.text('BOURSORAMA BANQUE'), findsOneWidget);

      // The name is our own construction from the account block, not something
      // the statement states — so the user renames it and the typed value wins.
      await tester.enterText(
        find.byKey(const Key('accountNameField')),
        'Mon livret',
      );
      await tester.enterText(
        find.byKey(const Key('accountOpeningBalanceField')),
        '0',
      );
      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();

      final call = controller.createCalls.single;
      expect(call.name, 'Mon livret');
      expect(call.institution, 'BOURSORAMA BANQUE');
      expect(call.type, AccountType.savings);
    },
  );

  testWidgets('the balance field is named for what it means at creation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    // Nothing has been imported yet, so the figure the user types is the
    // balance the account holds today — which is what a statement reports.
    expect(find.text('Solde actuel'), findsOneWidget);
    expect(find.text('Solde initial'), findsNothing);
    // Typed from scratch, nothing will correct it later, so no promise is made.
    expect(
      find.text(
        "Ajusté automatiquement d'après le solde déclaré par votre relevé lors du premier import.",
      ),
      findsNothing,
    );
  });

  testWidgets(
    'a dated statement balance is labelled with the day it holds at',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(),
          prefill: AccountPrefill(
            name: 'Courant ••4567',
            balanceMinor: 123456,
            balanceAsOf: DateTime(2026, 1, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The statement's closing balance was current the day it was cut, not
      // today — naming the day stops the user "fixing" it to today's figure.
      expect(find.text('Solde au 31/01/2026'), findsOneWidget);
      expect(find.text('Solde actuel'), findsNothing);
    },
  );

  testWidgets('an undated statement balance keeps the plain label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        controller: FakeAccountsController(),
        prefill: const AccountPrefill(
          name: 'Courant ••4567',
          balanceMinor: 123456,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solde actuel'), findsOneWidget);
  });

  testWidgets(
    'a statement declaring no balance says the balance will be adjusted',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(),
          prefill: const AccountPrefill(
            name: 'Courant ••4567',
            institution: 'Boursorama',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Ajusté automatiquement d'après le solde déclaré par votre relevé lors du premier import.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the balance a statement declares is stated, not asked for', (
    tester,
  ) async {
    final controller = FakeAccountsController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        prefill: const AccountPrefill(
          name: 'Courant ••4567',
          institution: 'Boursorama',
          balanceMinor: 123456,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing to remember and nothing to type: the figure is the statement's,
    // written the way a French user reads it (grouping and decimal comma —
    // spelled with the separators intl itself uses, not with ASCII ones).
    expect(
      find.text(NumberFormat.decimalPattern('fr').format(1234.56)),
      findsOneWidget,
    );
    expect(
      find.text('Repris du solde déclaré par votre relevé.'),
      findsOneWidget,
    );

    // Read from the file, so there is nothing to type into: a read-only plate,
    // not an input holding the same value.
    expect(
      find.descendant(
        of: find.byKey(const Key('accountOpeningBalanceField')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    // Submitted exactly as the statement declared it.
    expect(controller.createCalls.single.openingBalanceMinor, 123456);
  });

  testWidgets('the institution a statement names is stated, not asked for', (
    tester,
  ) async {
    final controller = FakeAccountsController();
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        prefill: const AccountPrefill(
          name: 'Courant ••4567',
          institution: 'Boursorama',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('accountInstitutionField')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
    expect(
      find.text("Repris de l'établissement déclaré par votre relevé."),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('accountOpeningBalanceField')),
      '0',
    );
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    // Still submitted, even though the user never touched the field.
    expect(controller.createCalls.single.institution, 'Boursorama');
  });

  testWidgets(
    'a statement that names no bank leaves the institution to be typed',
    (tester) async {
      final controller = FakeAccountsController();
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          prefill: const AccountPrefill(name: 'Courant ••4567'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accountInstitutionField')),
        'Ma banque',
      );
      await tester.enterText(
        find.byKey(const Key('accountOpeningBalanceField')),
        '0',
      );
      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();

      expect(controller.createCalls.single.institution, 'Ma banque');
    },
  );

  testWidgets('a deferred-debit card is offered as its own account type', (
    tester,
  ) async {
    final controller = FakeAccountsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('accountNameField')),
      'Carte Gold',
    );
    await tester.enterText(
      find.byKey(const Key('accountInstitutionField')),
      'BNP Paribas',
    );
    await tester.enterText(
      find.byKey(const Key('accountOpeningBalanceField')),
      '-320,40',
    );

    await tester.tap(find.byKey(const Key('accountTypeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carte à débit différé').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.type, AccountType.deferredCard);
  });

  testWidgets('the opening balance is editable, and prefilled, when editing', (
    tester,
  ) async {
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

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('accountOpeningBalanceField')),
    );
    expect(field.enabled, isTrue);
    // With transactions on top of it, the stored figure is only where the
    // account started — no longer what it holds.
    expect(find.text('Solde initial'), findsOneWidget);
    // Prefilled from the account, locale-formatted (fr: comma decimal).
    expect(find.text('100'), findsOneWidget);
    // The correction's blast radius, spelled out.
    expect(
      find.text(
        "Corriger cette valeur décale le solde du compte et son historique "
        "enregistré du même montant — aucune transaction n'est modifiée.",
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('accountNameField')),
      'Compte courant modifié',
    );
    await tester.enterText(
      find.byKey(const Key('accountOpeningBalanceField')),
      '80',
    );
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.updateCalls, hasLength(1));
    expect(controller.updateCalls.single.openingBalanceMinor, 8000);
  });

  testWidgets('the currency labels the balance rather than occupying a field', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    // It is a unit, not a value the form asks for: no field of its own, and
    // nothing to type into — it sits at the end of the amount it denominates.
    expect(find.byKey(const Key('accountCurrencyField')), findsNothing);
    expect(find.text('Devise'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('accountOpeningBalanceField')),
        matching: find.text('EUR'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a statement-declared currency outranks the profile, and is sent on',
    (tester) async {
      // The file says its figures are in dollars; the profile still says EUR.
      // The statement wins — it is describing this account, where the profile is
      // only the default for an account nothing declares a currency for.
      final controller = FakeAccountsController();
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          prefill: const AccountPrefill(
            name: 'Courant ••4567',
            institution: 'Chase',
            balanceMinor: 123456,
            currency: 'USD',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The balance is the statement's too, so it states rather than asks — the
      // currency rides on the read-only plate the same way.
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsNothing);

      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();

      expect(controller.createCalls.single.currency, 'USD');
    },
  );

  testWidgets('an account created by hand declares no currency of its own', (
    tester,
  ) async {
    final controller = FakeAccountsController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('accountNameField')),
      'Livret A',
    );
    await tester.enterText(
      find.byKey(const Key('accountInstitutionField')),
      'BNP Paribas',
    );
    await tester.enterText(
      find.byKey(const Key('accountOpeningBalanceField')),
      '100',
    );
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    // Omitted rather than echoed back from the profile: the backend's default
    // is the user's currency, and claiming it here would fake a declaration.
    expect(controller.createCalls.single.currency, isNull);
  });

  testWidgets(
    'the institution preview follows the typed name without claiming a match',
    (tester) async {
      await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accountInstitutionField')),
        'Revolut',
      );
      await tester.pumpAndSettle();

      // The chip the account will carry, shown live. A pinned brand hue is not
      // announced: the preview itself is the confirmation, and a name with no
      // pinned hue is not a failure to report.
      expect(
        tester.widget<InstitutionAvatar>(find.byType(InstitutionAvatar)).name,
        'Revolut',
      );
      expect(find.text('Logo reconnu'), findsNothing);
    },
  );

  testWidgets(
    'the type select keeps the field visible and drops its options below',
    (tester) async {
      await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
      await tester.pumpAndSettle();

      final anchor = tester.getRect(find.byKey(const Key('accountTypeField')));

      await tester.tap(find.byKey(const Key('accountTypeField')));
      await tester.pumpAndSettle();

      // The current choice is still on screen — the menu didn't land on top of
      // the field the user is changing.
      expect(find.text('Courant'), findsNWidgets(2));
      expect(
        tester.getRect(find.text('Épargne').last).top,
        greaterThanOrEqualTo(anchor.bottom),
      );
    },
  );
}
