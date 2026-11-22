import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/app_info.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/text_scale_provider.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/features/auth/application/auth_controller.dart';
import 'package:bastide/features/auth/domain/auth_user.dart';
import 'package:bastide/features/auth/domain/text_size_preference.dart';
import 'package:bastide/features/settings/presentation/settings_screen.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';
import '../../support/fake_auth_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _user = AuthUser(
  id: 'u1',
  email: 'camille@example.com',
  displayName: 'camille',
  locale: 'fr',
  currency: 'EUR',
);

Map<String, dynamic> _userJson(String textSize) => {
  'id': 'u1',
  'email': 'camille@example.com',
  'display_name': 'camille',
  'locale': 'fr',
  'currency': 'EUR',
  'avatar': 'monogram',
  'theme': 'dark',
  'text_size': textSize,
  'created_at': '2026-10-09T00:00:00Z',
};

/// The app's own wiring: the text scale from [textScaleProvider], applied
/// below the app as `app.dart` does.
class _Harness extends ConsumerWidget {
  const _Harness({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: locale,
    theme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        AppTextScaleScope(factor: ref.watch(textScaleProvider), child: child!),
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
        'savings_rate_goal_percent': 20,
      },
    );
    when(
      () => apiClient.get('/settings/updates'),
    ).thenAnswer((_) async => {'enabled': false, 'current_version': '0.1.0'});
  });

  Widget wrap({AuthUser user = _user, Locale locale = const Locale('fr')}) =>
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(initialUser: user),
          ),
          apiClientProvider.overrideWithValue(apiClient),
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
        ],
        child: _Harness(locale: locale),
      );

  /// How large a 13 px body text is drawn on the settings screen.
  double body(WidgetTester tester) => MediaQuery.textScalerOf(
    tester.element(find.text('Taille du texte')),
  ).scale(13);

  group('Paramètres › Taille du texte', () {
    testWidgets('offers normal, large and extra large, normal by default', (
      tester,
    ) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Taille du texte'), findsOneWidget);
      expect(
        find.text('Agrandit tout le texte de l’application.'),
        findsOneWidget,
      );
      for (final label in ['Normal', 'Grand', 'Très grand']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(body(tester), 13);
    });

    testWidgets('reads in English', (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
      for (final label in ['Normal', 'Large', 'Extra large']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('picking extra large saves it and rescales the app at once', (
      tester,
    ) async {
      useDesktopSurface(tester);
      when(
        () =>
            apiClient.put('/auth/me/text-size', body: {'text_size': 'xlarge'}),
      ).thenAnswer((_) async => {'user': _userJson('xlarge')});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsTextSizeXLargeOption')));
      await tester.pumpAndSettle();

      verify(
        () =>
            apiClient.put('/auth/me/text-size', body: {'text_size': 'xlarge'}),
      ).called(1);
      expect(body(tester), closeTo(13 * AppTextScale.xlarge, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused save puts the previous size back and says so', (
      tester,
    ) async {
      useDesktopSurface(tester);
      when(
        () => apiClient.put('/auth/me/text-size', body: {'text_size': 'large'}),
      ).thenThrow(Exception('offline'));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsTextSizeLargeOption')));
      await tester.pump();
      await tester.pump();

      expect(body(tester), 13);
      expect(
        find.text(
          'La taille du texte n’a pas pu être enregistrée. Rien n’a été '
          'modifié. Réessayez.',
        ),
        findsOneWidget,
      );
      // Let the toast leave.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('the panel holds at the largest size '
          '(${locale.languageCode})', (tester) async {
        useDesktopSurface(tester);
        await tester.pumpWidget(
          wrap(
            user: _user.withTextSize(TextSizePreference.xlarge),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
