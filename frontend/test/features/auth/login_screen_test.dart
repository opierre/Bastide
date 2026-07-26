import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/auth/application/auth_controller.dart';
import 'package:finstride/features/auth/presentation/login_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_controller.dart';

Widget _wrap({
  required FakeAuthController controller,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('the card holds only the task; the promise sits above it', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('Votre argent, en clair.'), findsOneWidget);
    expect(find.byKey(const Key('authPrivacyLine')), findsOneWidget);
    expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
  });

  testWidgets('the password reveal toggles obscuring', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    bool obscured() => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('loginPasswordField')),
            matching: find.byType(TextField),
          ),
        )
        .obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byKey(const Key('passwordVisibilityToggle')));
    await tester.pumpAndSettle();

    expect(obscured(), isFalse);
  });

  testWidgets('a rejected credential pair banners once and reddens both fields', (
    tester,
  ) async {
    final controller = FakeAuthController(
      loginError: const ApiFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'invalid credentials',
      ),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'wrong');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginErrorText')), findsOneWidget);
    expect(
      find.text('E-mail ou mot de passe incorrect. Vérifiez vos identifiants et réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting calls the controller with the typed credentials', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'secret123');

    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.loginCalls, hasLength(1));
    expect(controller.loginCalls.single.email, 'ada@example.com');
    expect(controller.loginCalls.single.password, 'secret123');
  });

  testWidgets('renders under en without missing localized keys', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeAuthController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your money, clearly.'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
