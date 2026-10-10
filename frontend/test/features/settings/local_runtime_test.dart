import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/settings/application/local_runtime_controller.dart';
import 'package:bastide/features/settings/domain/local_runtime.dart';
import 'package:bastide/features/settings/presentation/local_runtime_plate.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

const _path = '/settings/inference/runtime';

Map<String, dynamic> _runtime({
  String state = 'absent',
  int downloaded = 0,
  int total = 5172000000,
  String? error,
}) => {
  'state': state,
  'downloaded_bytes': downloaded,
  'total_bytes': total,
  'error': error,
  'model_tag': 'gemma-4-e4b-it',
};

void main() {
  late MockApiClient apiClient;

  setUp(() => apiClient = MockApiClient());

  void stubRead(Map<String, dynamic> json) =>
      when(() => apiClient.get(_path)).thenAnswer((_) async => json);

  Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(apiClient)],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SizedBox(width: 600, child: LocalRuntimePlate()),
      ),
    ),
  );

  String caption(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('settingsAiRuntimeCaption')))
      .data!;

  group('domain', () {
    test('parses every state and error code', () {
      final runtime = LocalRuntime.fromJson(
        _runtime(
          state: 'failed',
          downloaded: 10,
          total: 40,
          error: 'hash_mismatch',
        ),
      );

      expect(runtime.state, LocalRuntimeState.failed);
      expect(runtime.error, LocalRuntimeError.hashMismatch);
      expect(runtime.fraction, 0.25);
      expect(runtime.canResume, isTrue);
      expect(
        LocalRuntime.fromJson(_runtime(state: 'unsupported')).state,
        LocalRuntimeState.unsupported,
      );
    });
  });

  group('before downloading', () {
    testWidgets(
      'announces the size and the sources before anything is fetched',
      (tester) async {
        stubRead(_runtime());

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(
          caption(tester),
          'llama.cpp et Gemma 4 E4B — 5,2 Go, téléchargés une seule fois '
          'depuis GitHub et Hugging Face.',
        );
        expect(find.text('Télécharger'), findsOneWidget);
        verifyNever(() => apiClient.post(any()));
      },
    );

    testWidgets('offers to resume a partial download', (tester) async {
      stubRead(_runtime(downloaded: 1500000000));

      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        caption(tester),
        startsWith('1.5 GB of 5.2 GB already downloaded'),
      );
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('renders nothing where no build exists', (tester) async {
      stubRead(_runtime(state: 'unsupported', total: 0));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiRuntimePlate')), findsNothing);
    });

    testWidgets('renders nothing when the status cannot be read', (
      tester,
    ) async {
      when(
        () => apiClient.get(_path),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiRuntimePlate')), findsNothing);
    });
  });

  group('downloading', () {
    testWidgets('polls the progress until the install completes, then stops', (
      tester,
    ) async {
      stubRead(_runtime());
      when(
        () => apiClient.post('$_path/download'),
      ).thenAnswer((_) async => _runtime(state: 'downloading', downloaded: 0));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Télécharger'));
      await tester.pump();

      expect(
        find.byKey(const Key('settingsAiRuntimeProgress')),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);

      stubRead(_runtime(state: 'downloading', downloaded: 2586000000));
      await tester.pump(localRuntimePollInterval);
      await tester.pump();
      expect(caption(tester), 'Téléchargement… 2,6 Go sur 5,2 Go');

      stubRead(_runtime(state: 'installed', total: 0));
      await tester.pump(localRuntimePollInterval);
      await tester.pump();
      expect(caption(tester), 'Installé sur cet ordinateur.');
      expect(find.byKey(const Key('settingsAiRuntimeProgress')), findsNothing);

      clearInteractions(apiClient);
      await tester.pump(localRuntimePollInterval * 5);
      verifyNever(() => apiClient.get(_path));
    });

    testWidgets('cancelling stops the poll and keeps what was fetched', (
      tester,
    ) async {
      stubRead(_runtime(state: 'downloading', downloaded: 100000000));
      when(
        () => apiClient.post('$_path/cancel'),
      ).thenAnswer((_) async => _runtime(downloaded: 100000000));

      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Reprendre'), findsOneWidget);
      clearInteractions(apiClient);
      await tester.pump(localRuntimePollInterval * 3);
      verifyNever(() => apiClient.get(_path));
    });
  });

  group('failures', () {
    for (final (code, message) in [
      (
        'hash_mismatch',
        'Fichier refusé : il ne correspond pas à la version attendue. '
            "Rien n'a été installé.",
      ),
      (
        'network',
        'Téléchargement interrompu — vérifiez votre connexion, puis réessayez.',
      ),
      ('disk_full', 'Espace disque insuffisant — 5,2 Go nécessaires.'),
      ('extract', "L'archive du moteur n'a pas pu être extraite."),
    ]) {
      testWidgets('$code is explained and can be retried', (tester) async {
        stubRead(_runtime(state: 'failed', error: code));

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(caption(tester), message);
        expect(find.text('Réessayer'), findsOneWidget);
      });
    }
  });

  group('installed', () {
    testWidgets('removing asks first, then deletes', (tester) async {
      stubRead(_runtime(state: 'installed', total: 0));
      when(() => apiClient.delete(_path)).thenAnswer((_) async => _runtime());

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsAiRuntimeRemove')));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le moteur intégré ?'), findsOneWidget);
      verifyNever(() => apiClient.delete(_path));

      await tester.tap(find.byKey(const Key('settingsAiRuntimeRemoveConfirm')));
      await tester.pumpAndSettle();

      verify(() => apiClient.delete(_path)).called(1);
      expect(find.text('Télécharger'), findsOneWidget);
    });

    testWidgets('dismissing the confirmation deletes nothing', (tester) async {
      stubRead(_runtime(state: 'installed', total: 0));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsAiRuntimeRemove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsAiRuntimeRemoveCancel')));
      await tester.pumpAndSettle();

      verifyNever(() => apiClient.delete(_path));
      expect(find.text('Installé sur cet ordinateur.'), findsOneWidget);
    });
  });
}
