import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/widgets/primary_button.dart';
import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:finstride/features/auth/presentation/register_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_controller.dart';

Widget _wrap({required FakeAuthController controller, Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RegisterScreen(),
    ),
  );
}

/// Clears the strength meter's bar and the other required fields.
Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('registerDisplayNameField')), 'Ada Lovelace');
  await tester.enterText(find.byKey(const Key('registerEmailField')), 'ada@example.com');
  await tester.enterText(find.byKey(const Key('registerPasswordField')), 'Secret123!');
  await tester.pumpAndSettle();
}

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.byKey(const Key('registerSubmitButton')))
        .onPressed !=
    null;

void main() {
  testWidgets('renders the locale and currency selectors on the preferences plate', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registerLocaleFrenchOption')), findsOneWidget);
    expect(find.byKey(const Key('registerLocaleEnglishOption')), findsOneWidget);
    expect(find.byKey(const Key('registerCurrencyField')), findsOneWidget);
    expect(find.byKey(const Key('registerPreferencesNote')), findsOneWidget);
  });

  testWidgets('the currency reads as a value: code, symbol and name', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.textContaining('EUR (€) — Euro'), findsWidgets);
  });

  testWidgets('submit stays disabled until the password clears the meter', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(_submitEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('registerDisplayNameField')), 'Ada Lovelace');
    await tester.enterText(find.byKey(const Key('registerEmailField')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('registerPasswordField')), 'secret');
    await tester.pumpAndSettle();

    expect(find.text('Trop faible'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('registerPasswordField')), 'Secret123!');
    await tester.pumpAndSettle();

    expect(find.text('Robuste'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('a taken email is reported on the field, not as a banner', (
    tester,
  ) async {
    final controller = FakeAuthController(
      registerError: const ApiFailure(code: 'EMAIL_TAKEN', message: 'taken'),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    // Desktop-first layout in an 800×600 test viewport: the submit button sits
    // below the fold and has to be scrolled to before it can be tapped.
    await tester.ensureVisible(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cet e-mail est déjà utilisé — connectez-vous plutôt.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting calls the controller with the chosen locale and currency', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);

    await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
    await tester.pumpAndSettle();

    // The form is taller than the 800×600 test viewport (it's a desktop-first
    // layout), so the currency field has to be scrolled into view first.
    await tester.ensureVisible(find.byKey(const Key('registerCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerCurrencyField')));
    await tester.pumpAndSettle();

    // The field keeps stating the currency in force while the options are up,
    // so the choice being changed never leaves the screen.
    expect(find.textContaining('EUR ('), findsNWidgets(2));

    await tester.tap(
      find.ancestor(
        of: find.textContaining('USD ('),
        matching: find.byType(MenuItemButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.registerCalls, hasLength(1));
    final call = controller.registerCalls.single;
    expect(call.email, 'ada@example.com');
    expect(call.password, 'Secret123!');
    expect(call.displayName, 'Ada Lovelace');
    expect(call.locale, 'en');
    expect(call.currency, 'USD');
  });

  testWidgets('renders under fr without missing localized keys', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    // The card carries no heading — the lockup and the privacy line above it
    // say what the screen is, so the submit label is the assertable title.
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('Déjà un compte ? Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders under en without missing localized keys', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeAuthController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Already have an account? Log in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
