import 'package:bastide/core/session/current_user_provider.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/inline_banner.dart';
import 'package:bastide/core/widgets/institution_avatar.dart';
import 'package:bastide/core/widgets/labeled_field.dart';
import 'package:bastide/core/widgets/note_line.dart';
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

Account _checking({
  String id = 'checking-1',
  String institution = 'BNP Paribas',
}) => Account(
  id: id,
  name: 'Courant',
  type: AccountType.checking,
  institution: institution,
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

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

  testWidgets(
    'a card statement asks how the card is debited instead of the type list',
    (tester) async {
      final controller = FakeAccountsController();
      await tester.pumpWidget(
        _wrap(
          controller: controller,
          prefill: const AccountPrefill(
            name: 'Carte ••9876',
            institution: 'BOURSORAMA BANQUE',
            type: AccountType.deferredCard,
            balanceMinor: -45210,
            isCardStatement: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountCardDebitField')), findsOneWidget);
      expect(find.byKey(const Key('accountTypeField')), findsNothing);
      expect(find.text('Débit de la carte'), findsOneWidget);

      // Deferred debit is the proposal; the user answers credit instead.
      await tester.tap(find.byKey(const Key('accountCardDebitCredit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();

      expect(controller.createCalls.single.type, AccountType.credit);
      expect(controller.createCalls.single.openingBalanceMinor, -45210);
    },
  );

  testWidgets('a card statement left as proposed creates a deferred card', (
    tester,
  ) async {
    final controller = FakeAccountsController(
      initialAccounts: [
        _checking(id: 'other-bank'),
        _checking(id: 'same-bank', institution: 'BOURSORAMA BANQUE'),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        prefill: const AccountPrefill(
          name: 'Carte ••9876',
          institution: 'BOURSORAMA BANQUE',
          type: AccountType.deferredCard,
          balanceMinor: 0,
          isCardStatement: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.type, AccountType.deferredCard);
    // The only current account at the card's bank is the obvious payer.
    expect(controller.createCalls.single.settlementAccountId, 'same-bank');
  });

  testWidgets('the balance field is named for what it means at creation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    // « Solde initial » (`05-accounts.md`, proposal v6): the figure the
    // account starts from.
    expect(find.text('Solde initial'), findsOneWidget);
    expect(find.text('Solde actuel'), findsNothing);
    // Typed from scratch, nothing will correct it later, so no promise is made.
    expect(
      find.text(
        "Ajusté automatiquement d’après le solde déclaré par votre relevé lors du premier import.",
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

    expect(find.text('Solde initial'), findsOneWidget);
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
          "Ajusté automatiquement d’après le solde déclaré par votre relevé lors du premier import.",
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
      find.text("Repris de l’établissement déclaré par votre relevé."),
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
    final controller = FakeAccountsController(initialAccounts: [_checking()]);
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
    expect(controller.createCalls.single.settlementAccountId, 'checking-1');
  });

  testWidgets('a card the form cannot place asks for its settlement account', (
    tester,
  ) async {
    final controller = FakeAccountsController(
      initialAccounts: [
        _checking(id: 'a', institution: 'LCL'),
        _checking(id: 'b', institution: 'Société Générale'),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        prefill: const AccountPrefill(
          name: 'Carte ••9876',
          institution: 'BOURSORAMA BANQUE',
          balanceMinor: 0,
          isCardStatement: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls, isEmpty);
    expect(find.text('Choisissez le compte prélevé.'), findsOneWidget);

    // The card fields sit under the institution, below the fold of the
    // test window: the body scrolls to them.
    await tester.ensureVisible(find.byKey(const Key('accountSettlementField')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accountSettlementField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courant · LCL').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.settlementAccountId, 'a');
  });

  testWidgets('the account a statement file proposes outranks the guess', (
    tester,
  ) async {
    final controller = FakeAccountsController(
      initialAccounts: [
        _checking(id: 'guess', institution: 'BOURSORAMA BANQUE'),
        _checking(id: 'sibling', institution: 'Joint'),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        controller: controller,
        prefill: const AccountPrefill(
          name: 'Carte ••9876',
          institution: 'BOURSORAMA BANQUE',
          balanceMinor: 0,
          isCardStatement: true,
          settlementAccountId: 'sibling',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.createCalls.single.settlementAccountId, 'sibling');
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
        "enregistré du même montant. Aucune transaction n’est modifiée.",
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

  testWidgets('the currency is shown read-only and labels the balance', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
    await tester.pumpAndSettle();

    // One currency per user: stated, never asked for (`05-accounts.md`).
    final currency = find.byKey(const Key('accountCurrencyField'));
    expect(currency, findsOneWidget);
    expect(find.byType(ReadOnlyField), findsOneWidget);
    expect(
      find.descendant(of: currency, matching: find.text('EUR, euro')),
      findsOneWidget,
    );
    expect(find.text('Devise'), findsOneWidget);
    expect(find.text('La devise est celle de votre profil.'), findsOneWidget);
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

  group('proposal v6 (m-accounts)', () {
    final card = Account(
      id: 'card-1',
      name: 'Carte Voyage',
      type: AccountType.deferredCard,
      institution: 'Banque Exemple',
      currency: 'EUR',
      settlementAccountId: 'checking-1',
      openingBalanceMinor: -31240,
      balanceMinor: -31240,
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    testWidgets('« Nouveau compte »: 480, the fields in the v6 order', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
      await tester.pumpAndSettle();

      final modal = tester.widget<AppModal>(find.byType(AppModal));
      expect(modal.width, AppModalSizes.w480);
      expect(modal.title, 'Nouveau compte');
      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(top('Nom'), lessThan(top('Type')));
      expect(top('Type'), lessThan(top('Établissement')));
      expect(top('Établissement'), lessThan(top('Solde initial')));
      expect(top('Solde initial'), lessThan(top('Devise')));
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      // Amounts are right-aligned (`00` §6).
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('accountOpeningBalanceField')),
                matching: find.byType(TextField),
              ),
            )
            .textAlign,
        TextAlign.end,
      );
    });

    testWidgets('from a statement, the prefill is a note, not a banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(),
          prefill: const AccountPrefill(name: 'Livret A'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(NoteLine),
          matching: find.text('Champs pré-remplis depuis votre relevé.'),
        ),
        findsOneWidget,
      );
      expect(find.byType(InlineBanner), findsNothing);
    });

    testWidgets(
      '« Modifier le compte » for a card: Débit de la carte and Prélevée sur '
      'follow the institution',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            controller: FakeAccountsController(
              initialAccounts: [_checking(), card],
            ),
            initial: card,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Modifier le compte'), findsOneWidget);
        expect(find.byKey(const Key('accountTypeField')), findsOneWidget);
        double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
        expect(
          top(const Key('accountInstitutionField')),
          lessThan(top(const Key('accountCardDebitField'))),
        );
        expect(
          top(const Key('accountCardDebitField')),
          lessThan(top(const Key('accountSettlementField'))),
        );
        expect(
          top(const Key('accountSettlementField')),
          lessThan(top(const Key('accountOpeningBalanceField'))),
        );
        expect(
          find.text(
            'Une carte à débit différé est prélevée en une fois sur votre '
            'compte courant chaque mois.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the long form scrolls its body between hairlines', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          controller: FakeAccountsController(
            initialAccounts: [_checking(), card],
          ),
          initial: card,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appModalHeaderHairline')), findsOneWidget);
      expect(find.byKey(const Key('appModalFooterHairline')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing « Crédit » turns the card into a credit account', (
      tester,
    ) async {
      final controller = FakeAccountsController(
        initialAccounts: [_checking(), card],
      );
      await tester.pumpWidget(_wrap(controller: controller, initial: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accountCardDebitCredit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('accountCardDebitField')), findsNothing);
      expect(find.byKey(const Key('accountSettlementField')), findsNothing);
      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();
      expect(controller.updateCalls.single.type, AccountType.credit);
      expect(controller.updateCalls.single.settlementAccountId, isNull);
    });

    testWidgets('typed input asks before it is dropped', (tester) async {
      await tester.pumpWidget(_wrap(controller: FakeAccountsController()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accountNameField')),
        'Compte joint',
      );
      // The frame learns the form is dirty on the next frame.
      await tester.pump();
      await tester.tap(find.byKey(const Key('accountFormCancelButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
    });

    testWidgets('a failed save shows the error at the top, input kept', (
      tester,
    ) async {
      final controller = FakeAccountsController()
        ..errorOnCreate = Exception('boom');
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accountNameField')),
        'Compte joint',
      );
      await tester.enterText(
        find.byKey(const Key('accountInstitutionField')),
        'Banque Exemple',
      );
      await tester.enterText(
        find.byKey(const Key('accountOpeningBalanceField')),
        '1250',
      );
      await tester.tap(find.byKey(const Key('accountFormSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
      expect(find.text('Compte joint'), findsOneWidget);
    });
  });
}
