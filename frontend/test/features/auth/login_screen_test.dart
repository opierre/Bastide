import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/presentation/login_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_controller.dart';

Widget _wrap({
  required FakeAuthController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    ),
  );
}

/// The reference frame of `00-design-system.md`.
void _useReferenceFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

TextField _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key)));

Color? _borderColor(WidgetTester tester, String key) {
  final border = _field(tester, key).decoration?.enabledBorder;
  return border is OutlineInputBorder ? border.borderSide.color : null;
}

Future<void> _type(
  WidgetTester tester,
  String identifier,
  String password,
) async {
  await tester.enterText(
    find.byKey(const Key('loginIdentifierField')),
    identifier,
  );
  await tester.enterText(find.byKey(const Key('loginPasswordField')), password);
}

void main() {
  testWidgets('one 320 px column on the ground: no card, one privacy line', (
    tester,
  ) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('loginSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(
      tester.getSize(find.byKey(const Key('loginSubmitButton'))).height,
      AppSizes.buttonLarge,
    );
    expect(find.text("E-mail ou nom d'utilisateur"), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Mot de passe oublié'), findsOneWidget);
    expect(find.byKey(const Key('authPrivacyLine')), findsOneWidget);
    expect(
      find.text('Vos données restent sur cet ordinateur.'),
      findsOneWidget,
    );
    // Nothing raised or shadowed: the v1 card is gone.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).boxShadow != null,
      ),
      findsNothing,
    );
  });

  testWidgets('the password reveal toggles obscuring', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(_field(tester, 'loginPasswordField').obscureText, isTrue);

    await tester.tap(find.byKey(const Key('passwordVisibilityToggle')));
    await tester.pumpAndSettle();

    expect(_field(tester, 'loginPasswordField').obscureText, isFalse);
  });

  testWidgets('submitting empty fields shows the field errors', (tester) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    // Untouched, the form shows no error and the button is enabled.
    expect(
      find.text("L'e-mail ou le nom d'utilisateur est requis."),
      findsNothing,
    );
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const Key('loginSubmitButton')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text("L'e-mail ou le nom d'utilisateur est requis."),
      findsOneWidget,
    );
    expect(find.text('Le mot de passe est requis.'), findsOneWidget);
    expect(controller.loginCalls, isEmpty);
  });

  testWidgets(
    'a rejected pair reddens both fields and says so once, under the password',
    (tester) async {
      final controller = FakeAuthController(
        loginError: const ApiFailure(
          code: 'INVALID_CREDENTIALS',
          message: 'invalid credentials',
        ),
      );
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();
      final negative = AppColors.dark.negative;

      await _type(tester, 'ada@example.com', 'wrong');
      await tester.tap(find.byKey(const Key('loginSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('Identifiant ou mot de passe incorrect.'),
        findsOneWidget,
      );
      expect(_borderColor(tester, 'loginIdentifierField'), negative);
      expect(_borderColor(tester, 'loginPasswordField'), negative);
      // Under the password field, not above the form.
      expect(
        tester
            .getTopLeft(find.text('Identifiant ou mot de passe incorrect.'))
            .dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('loginPasswordField'))).dy,
        ),
      );
    },
  );

  testWidgets('a rejected pair is reported in English too', (tester) async {
    final controller = FakeAuthController(
      loginError: const ApiFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'invalid credentials',
      ),
    );
    await tester.pumpWidget(
      _wrap(controller: controller, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await _type(tester, 'ada.lovelace', 'wrong');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email, username or password.'), findsOneWidget);
  });

  testWidgets('loading: spinner label, fields disabled, same width', (
    tester,
  ) async {
    final hold = Completer<void>();
    await tester.pumpWidget(_wrap(controller: FakeAuthController(hold: hold)));
    await tester.pumpAndSettle();
    final width = tester
        .getSize(find.byKey(const Key('loginSubmitButton')))
        .width;

    await _type(tester, 'ada@example.com', 'secret123');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pump();

    expect(find.text('Connexion…'), findsOneWidget);
    expect(_field(tester, 'loginIdentifierField').enabled, isFalse);
    expect(_field(tester, 'loginPasswordField').enabled, isFalse);
    expect(
      tester.getSize(find.byKey(const Key('loginSubmitButton'))).width,
      width,
    );

    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('submitting calls the controller with the typed credentials', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _type(tester, 'ada@example.com', 'secret123');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.loginCalls, hasLength(1));
    expect(controller.loginCalls.single.identifier, 'ada@example.com');
    expect(controller.loginCalls.single.password, 'secret123');
  });

  testWidgets('Enter in the e-mail field submits too', (tester) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _type(tester, 'ada@example.com', 'secret123');
    await tester.tap(find.byKey(const Key('loginIdentifierField')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.loginCalls, hasLength(1));
  });

  testWidgets('a username is submitted as the identifier, like an email', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _type(tester, '  ada.lovelace ', 'secret123');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.loginCalls.single.identifier, 'ada.lovelace');
  });

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    testWidgets('renders in the $name theme at the reference frame', (
      tester,
    ) async {
      _useReferenceFrame(tester);
      await tester.pumpWidget(
        _wrap(controller: FakeAuthController(), theme: theme),
      );
      await tester.pumpAndSettle();

      final colors = theme.extension<AppColors>()!;
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        colors.bg,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders under en with the same geometry', (tester) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeAuthController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your data stays on this computer.'), findsOneWidget);
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('loginSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(tester.takeException(), isNull);
  });
}
