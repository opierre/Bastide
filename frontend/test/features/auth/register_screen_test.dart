import 'package:finstride/core/theme/app_theme.dart';
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

void main() {
  testWidgets('renders the locale and currency selectors', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registerLocaleFrenchOption')), findsOneWidget);
    expect(find.byKey(const Key('registerLocaleEnglishOption')), findsOneWidget);
    expect(find.byKey(const Key('registerCurrencyField')), findsOneWidget);
  });

  testWidgets('submitting calls the controller with the chosen locale and currency', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('registerEmailField')), 'ada@example.com');
    await tester.enterText(find.byKey(const Key('registerPasswordField')), 'secret123');
    await tester.enterText(find.byKey(const Key('registerDisplayNameField')), 'Ada Lovelace');

    await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registerCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.registerCalls, hasLength(1));
    final call = controller.registerCalls.single;
    expect(call.email, 'ada@example.com');
    expect(call.password, 'secret123');
    expect(call.displayName, 'Ada Lovelace');
    expect(call.locale, 'en');
    expect(call.currency, 'USD');
  });

  testWidgets('renders under fr without missing localized keys', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders under en without missing localized keys', (tester) async {
    await tester.pumpWidget(
      _wrap(controller: FakeAuthController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
