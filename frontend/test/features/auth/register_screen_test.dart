import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/l10n/locale_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/presentation/register_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_controller.dart';

/// The app's own wiring: the locale comes from [localeProvider], so the
/// language segment switches the screen like it does in the app.
Widget _wrap({
  required FakeAuthController controller,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => controller),
      localeProvider.overrideWith(() => _FixedLocale(locale)),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        theme: theme ?? AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ),
    ),
  );
}

class _FixedLocale extends LocaleController {
  _FixedLocale(this.initial);

  final Locale initial;

  @override
  Locale build() => initial;
}

/// The reference frame of `00-design-system.md`.
void _useReferenceFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _validPassword = 'correct-horse-7';

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('registerDisplayNameField')),
    'ada.lovelace',
  );
  await tester.enterText(
    find.byKey(const Key('registerEmailField')),
    'ada@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('registerPasswordField')),
    _validPassword,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('registerSubmitButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('registerSubmitButton')));
  await tester.pumpAndSettle();
}

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.byKey(const Key('registerSubmitButton')))
        .onPressed !=
    null;

void main() {
  testWidgets('the v2 column: no strength meter, the currency microcopy', (
    tester,
  ) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.text("Nom d’utilisateur"), findsOneWidget);
    expect(find.text('Nom affiché'), findsNothing);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Devise'), findsOneWidget);
    expect(
      find.text(
        'La langue se change dans les paramètres. La devise est définitive et s’applique à tous vos comptes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Déjà un compte ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(
      find.text('Vos données restent sur cet ordinateur.'),
      findsOneWidget,
    );
    expect(find.text('Robuste'), findsNothing);
    expect(find.text('Trop faible'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('registerSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(
      tester.getSize(find.byKey(const Key('registerCurrencyField'))).height,
      AppSizes.toolbarSelect,
    );
  });

  testWidgets('the currency reads « EUR, euro »', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('EUR, euro'), findsOneWidget);
  });

  testWidgets('empty: submit disabled, the password minimum as guidance', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    expect(_submitEnabled(tester), isFalse);
    expect(find.text('12 caractères minimum.'), findsOneWidget);
  });

  testWidgets('valid: the check form of the helper and submit enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);

    expect(find.byKey(const Key('newPasswordHelperValid')), findsOneWidget);
    expect(find.text('15 caractères. Le minimum est de 12.'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('a short password left behind turns into « Encore n »', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registerPasswordField')));
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'short-pw',
    );
    await tester.pumpAndSettle();
    // Still typing: guidance, not an error.
    expect(find.text('12 caractères minimum.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registerEmailField')));
    await tester.pumpAndSettle();

    expect(find.text('Encore 4 caractères.'), findsOneWidget);
    final border =
        tester
                .widget<TextField>(
                  find.byKey(const Key('registerPasswordField')),
                )
                .decoration
                ?.enabledBorder
            as OutlineInputBorder?;
    expect(border?.borderSide.color, AppColors.dark.negative);
    expect(_submitEnabled(tester), isFalse);
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
    await _tapSubmit(tester);

    expect(
      find.text('Cet e-mail a déjà un compte. Connectez-vous.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('registerErrorText')), findsNothing);
  });

  testWidgets('a malformed name is flagged and keeps submit disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    expect(_submitEnabled(tester), isTrue);

    await tester.enterText(
      find.byKey(const Key('registerDisplayNameField')),
      'Ada@Lovelace',
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '3 à 32 caractères : lettres sans accent, chiffres, espaces, '
        '« . », « _ » ou « - ».',
      ),
      findsOneWidget,
    );
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('a name with a space is accepted and sent as typed', (
    tester,
  ) async {
    final controller = FakeAuthController();
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('registerDisplayNameField')),
      'Camille Dubois',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('lettres sans accent'), findsNothing);
    expect(_submitEnabled(tester), isTrue);
    await _tapSubmit(tester);
    expect(controller.registerCalls.single.displayName, 'Camille Dubois');
  });

  testWidgets('a taken name is reported on its field', (tester) async {
    final controller = FakeAuthController(
      registerError: const ApiFailure(
        code: 'DISPLAY_NAME_TAKEN',
        message: 'taken',
      ),
    );
    await tester.pumpWidget(_wrap(controller: controller));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapSubmit(tester);

    expect(find.text("Ce nom d’utilisateur est déjà pris."), findsOneWidget);
  });

  testWidgets('loading: « Création… » and the fields disabled', (tester) async {
    final hold = Completer<void>();
    await tester.pumpWidget(_wrap(controller: FakeAuthController(hold: hold)));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.ensureVisible(find.byKey(const Key('registerSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmitButton')));
    await tester.pump();

    expect(find.text('Création…'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('registerEmailField')))
          .enabled,
      isFalse,
    );

    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('choosing English switches the screen at once', (tester) async {
    await tester.pumpWidget(_wrap(controller: FakeAuthController()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('registerLocaleEnglishOption')),
    );
    await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Display name'), findsNothing);
    expect(find.text('EUR, euro'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets(
    'submitting calls the controller with the chosen locale and currency',
    (tester) async {
      final controller = FakeAuthController();
      await tester.pumpWidget(_wrap(controller: controller));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);

      await tester.ensureVisible(
        find.byKey(const Key('registerLocaleEnglishOption')),
      );
      await tester.tap(find.byKey(const Key('registerLocaleEnglishOption')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('registerCurrencyField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registerCurrencyField')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(
          of: find.text('USD, US dollar'),
          matching: find.byType(MenuItemButton),
        ),
      );
      await tester.pumpAndSettle();

      await _tapSubmit(tester);

      expect(controller.registerCalls, hasLength(1));
      final call = controller.registerCalls.single;
      expect(call.email, 'ada@example.com');
      expect(call.password, _validPassword);
      expect(call.displayName, 'ada.lovelace');
      expect(call.locale, 'en');
      expect(call.currency, 'USD');
    },
  );

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

  testWidgets('renders under en with the English segment selected', (
    tester,
  ) async {
    _useReferenceFrame(tester);
    await tester.pumpWidget(
      _wrap(controller: FakeAuthController(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('12 characters minimum.'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('registerSubmitButton'))).width,
      AppSizes.authColumn,
    );
    expect(tester.takeException(), isNull);
  });
}
