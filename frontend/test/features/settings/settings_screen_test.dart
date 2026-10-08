import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/l10n/locale_provider.dart';
import 'package:finstride/core/session/current_user_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/features/auth/domain/auth_user.dart';
import 'package:finstride/features/settings/presentation/settings_screen.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'camille.dubois@proton.me',
  displayName: 'Camille Dubois',
  locale: 'fr',
  currency: 'EUR',
);

/// Mounts the screen under the real [localeProvider] so switching the language
/// re-renders it exactly as it would in the app.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeProvider),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SettingsScreen()),
    );
  }
}

/// Données now renders the local-AI card, which reads `/settings` — so the
/// screen needs a stubbed client even in the tests that never open that tab.
Widget _wrap() {
  final apiClient = _MockApiClient();
  when(() => apiClient.get('/settings')).thenAnswer(
    (_) async => {
      'ai_enabled': false,
      'inference_base_url': 'http://127.0.0.1:11434/v1',
      'model_tag': null,
      'confidence_threshold': 0.8,
    },
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      apiClientProvider.overrideWithValue(apiClient),
    ],
    child: const _Harness(),
  );
}

void main() {
  testWidgets('opens on preferences with the four sections listed', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (final section in SettingsSection.values) {
      expect(
        find.byKey(Key('settingsSection-${section.name}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('settingsCurrencyField')), findsOneWidget);
  });

  testWidgets('switching the language applies immediately, including formats', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('14/05/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsLocaleEnglishOption')));
    await tester.pumpAndSettle();

    // The promise under the control is "applies immediately" — no save step.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('5/14/2026'), findsOneWidget);
  });

  testWidgets('the currency is a settled value, shown as symbol then code', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('€ — EUR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('settingsCurrencyField')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
  });

  testWidgets('Données carries the local-AI card', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSection-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsAiCard')), findsOneWidget);
    expect(find.byKey(const Key('settingsBackupCard')), findsOneWidget);
    // The way out is offered above the way through: export, then danger zone.
    expect(find.byKey(const Key('settingsDangerZoneCard')), findsOneWidget);
    // Préférences is unchanged by the Données amendments: language, currency and
    // formats stay there, and none of them followed the card into Données.
    expect(find.byKey(const Key('settingsCurrencyField')), findsNothing);
  });

  testWidgets('Profil offers the username and recovery code cards', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSection-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsDisplayNameCard')), findsOneWidget);
    expect(find.byKey(const Key('settingsRecoveryCard')), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsNothing);
  });

  testWidgets('about states the version and the local-privacy promise', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsSection-about')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsAppVersion')), findsOneWidget);
    expect(find.textContaining('restent sur cet ordinateur'), findsOneWidget);
  });
}
