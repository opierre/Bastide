import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/settings/application/update_check_controller.dart';
import 'package:bastide/features/settings/presentation/update_check_card.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _status({
  bool enabled = true,
  String? latest,
  bool available = false,
  bool reachable = true,
}) => {
  'enabled': enabled,
  'current_version': '0.1.0',
  'latest_version': latest,
  'update_available': available,
  'release_url': available
      ? 'https://github.com/opierre/Bastide/releases/tag/v$latest'
      : null,
  'checked_at': latest == null ? null : '2026-10-11T09:00:00Z',
  'reachable': reachable,
};

void main() {
  late _MockApiClient apiClient;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() => apiClient = _MockApiClient());

  void stubStatus(Map<String, dynamic> json) {
    when(
      () => apiClient.get('/settings/updates'),
    ).thenAnswer((_) async => json);
  }

  void stubPatch() {
    when(
      () => apiClient.patch('/settings', body: any(named: 'body')),
    ).thenAnswer(
      (_) async => {
        'ai_enabled': false,
        'inference_base_url': 'http://127.0.0.1:11434/v1',
        'model_tag': null,
        'confidence_threshold': 0.8,
        'update_check_enabled': true,
      },
    );
  }

  group('controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
    });

    test('reads the status on load', () async {
      stubStatus(_status(latest: '0.2.0', available: true));

      final state = await container.read(updateCheckControllerProvider.future);

      expect(state.status.enabled, isTrue);
      expect(state.status.updateAvailable, isTrue);
      expect(state.status.latestVersion, '0.2.0');
      expect(
        state.status.releaseUrl,
        Uri.parse('https://github.com/opierre/Bastide/releases/tag/v0.2.0'),
      );
    });

    test('opting in saves the choice, then reads the first check', () async {
      stubStatus(_status(enabled: false));
      stubPatch();
      await container.read(updateCheckControllerProvider.future);
      stubStatus(_status(latest: '0.1.0'));

      await container
          .read(updateCheckControllerProvider.notifier)
          .setEnabled(true);

      verify(
        () =>
            apiClient.patch('/settings', body: {'update_check_enabled': true}),
      ).called(1);
      final state = container.read(updateCheckControllerProvider).value!;
      expect(state.status.enabled, isTrue);
      expect(state.status.latestVersion, '0.1.0');
      expect(state.isBusy, isFalse);
    });

    test('a refused patch leaves the stored choice', () async {
      stubStatus(_status(enabled: false));
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenThrow(Exception('sidecar down'));
      await container.read(updateCheckControllerProvider.future);

      await container
          .read(updateCheckControllerProvider.notifier)
          .setEnabled(true);

      final state = container.read(updateCheckControllerProvider).value!;
      expect(state.status.enabled, isFalse);
      expect(state.isBusy, isFalse);
    });
  });

  group('card', () {
    Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: MaterialApp(
        locale: locale,
        theme: appDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: UpdateCheckCard()),
      ),
    );

    testWidgets('off: no status, only what turning it on would send', (
      tester,
    ) async {
      stubStatus(_status(enabled: false));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Mises à jour'), findsOneWidget);
      expect(find.byKey(const Key('settingsUpdateStatus')), findsNothing);
      expect(find.byKey(const Key('settingsUpdateAvailable')), findsNothing);
      expect(
        find.textContaining('Rien d\'autre n\'est envoyé'),
        findsOneWidget,
      );
    });

    testWidgets('a newer release is offered with a download link', (
      tester,
    ) async {
      stubStatus(_status(latest: '0.2.0', available: true));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Bastide 0.2.0 est disponible'), findsOneWidget);
      expect(find.text('Vous utilisez la version 0.1.0.'), findsOneWidget);
      expect(find.byKey(const Key('settingsUpdateDownload')), findsOneWidget);
    });

    testWidgets('the same version reads as up to date', (tester) async {
      stubStatus(_status(latest: '0.1.0'));

      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        find.text('You are on the latest version (0.1.0).'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settingsUpdateDownload')), findsNothing);
    });

    testWidgets('offline says GitHub could not be reached', (tester) async {
      stubStatus(_status(reachable: false));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('GitHub n\'a pas pu être joint'),
        findsOneWidget,
      );
    });

    testWidgets('offline still shows a newer release found earlier', (
      tester,
    ) async {
      stubStatus(_status(latest: '0.2.0', available: true, reachable: false));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsUpdateAvailable')), findsOneWidget);
    });

    testWidgets('tapping the toggle opts in', (tester) async {
      stubStatus(_status(enabled: false));
      stubPatch();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      stubStatus(_status(latest: '0.2.0', available: true));
      await tester.tap(find.byKey(const Key('settingsUpdateToggle')));
      await tester.pumpAndSettle();

      verify(
        () =>
            apiClient.patch('/settings', body: {'update_check_enabled': true}),
      ).called(1);
      expect(find.byKey(const Key('settingsUpdateAvailable')), findsOneWidget);
    });

    testWidgets('a sidecar that cannot be asked says so', (tester) async {
      when(
        () => apiClient.get('/settings/updates'),
      ).thenThrow(Exception('sidecar down'));

      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Update status unavailable.'), findsOneWidget);
    });
  });
}
