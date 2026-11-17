import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/app_info.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/theme_mode_provider.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/theme_preference.dart';
import 'package:bastide/features/settings/presentation/settings_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'camille@example.com',
  displayName: 'camille',
  locale: 'fr',
  currency: 'EUR',
);

Map<String, dynamic> _userJson(String theme) => {
  'id': 'u1',
  'email': 'camille@example.com',
  'display_name': 'camille',
  'locale': 'fr',
  'currency': 'EUR',
  'avatar': 'monogram',
  'theme': theme,
  'created_at': '2026-10-09T00:00:00Z',
};

/// The app's own wiring: both themes, the mode from [themeModeProvider].
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: const Locale('fr'),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: SettingsScreen()),
  );
}

void main() {
  late _MockApiClient apiClient;

  setUp(() {
    apiClient = _MockApiClient();
    when(() => apiClient.get('/settings')).thenAnswer(
      (_) async => {
        'ai_enabled': false,
        'inference_base_url': 'http://127.0.0.1:11434/v1',
        'model_tag': null,
        'confidence_threshold': 0.8,
      },
    );
    when(
      () => apiClient.get('/settings/updates'),
    ).thenAnswer((_) async => {'enabled': false, 'current_version': '0.1.0'});
  });

  Widget wrap({AuthUser user = _user}) => ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(initialUser: user),
      ),
      apiClientProvider.overrideWithValue(apiClient),
      appVersionProvider.overrideWith((ref) async => '0.1.0'),
    ],
    child: const _Harness(),
  );

  Color ground(WidgetTester tester) => Theme.of(
    tester.element(find.byType(SettingsScreen)),
  ).extension<AppColors>()!.bg;

  group('ThemePreference.fromWire', () {
    test('reads each value and falls back to dark', () {
      expect(ThemePreference.fromWire('system'), ThemePreference.system);
      expect(ThemePreference.fromWire('light'), ThemePreference.light);
      expect(ThemePreference.fromWire('dark'), ThemePreference.dark);
      for (final wire in [null, '', 'sepia']) {
        expect(ThemePreference.fromWire(wire), ThemePreference.dark);
      }
    });
  });

  group('themeModeProvider', () {
    test('is dark before anyone signs in', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(FakeAuthController.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('follows the signed-in user', () async {
      for (final (preference, mode) in [
        (ThemePreference.system, ThemeMode.system),
        (ThemePreference.dark, ThemeMode.dark),
        (ThemePreference.light, ThemeMode.light),
      ]) {
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () =>
                  FakeAuthController(initialUser: _user.withTheme(preference)),
            ),
          ],
        );
        await container.read(authControllerProvider.future);

        expect(container.read(themeModeProvider), mode);
        container.dispose();
      }
    });
  });

  group('Paramètres › Thème', () {
    testWidgets('offers system, dark and light, dark selected by default', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Thème'), findsOneWidget);
      expect(find.text('Sombre, clair, ou celui de votre système.'), findsOne);
      for (final label in ['Système', 'Sombre', 'Clair']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(ground(tester), AppColors.dark.bg);
    });

    testWidgets('picking light saves it and re-renders the app at once', (
      tester,
    ) async {
      when(
        () => apiClient.put('/auth/me/theme', body: {'theme': 'light'}),
      ).thenAnswer((_) async => {'user': _userJson('light')});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsThemeLightOption')));
      await tester.pumpAndSettle();

      verify(
        () => apiClient.put('/auth/me/theme', body: {'theme': 'light'}),
      ).called(1);
      expect(ground(tester), AppColors.light.bg);
    });

    testWidgets('a refused save puts the previous theme back and says so', (
      tester,
    ) async {
      when(
        () => apiClient.put('/auth/me/theme', body: {'theme': 'light'}),
      ).thenThrow(Exception('offline'));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsThemeLightOption')));
      await tester.pump();
      await tester.pump();

      expect(ground(tester), AppColors.dark.bg);
      expect(
        find.text(
          "Le thème n'a pas pu être enregistré. Rien n'a été modifié. "
          'Réessayez.',
        ),
        findsOneWidget,
      );
      // Let the toast leave.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
