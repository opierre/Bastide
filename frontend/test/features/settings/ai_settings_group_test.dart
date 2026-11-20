import 'dart:async';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_slider.dart';
import 'package:bastide/core/widgets/app_toggle.dart';
import 'package:bastide/features/settings/application/settings_controller.dart';
import 'package:bastide/features/settings/presentation/ai_settings_group.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/desktop_surface.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _settingsJson({
  bool aiEnabled = true,
  String baseUrl = 'http://127.0.0.1:11434/v1',
  String? modelTag = 'gemma3n:e4b',
  double threshold = 0.8,
}) => {
  'ai_enabled': aiEnabled,
  'inference_base_url': baseUrl,
  'model_tag': modelTag,
  'confidence_threshold': threshold,
};

Map<String, dynamic> _healthJson({
  bool reachable = true,
  List<String> models = const ['gemma3n:e4b', 'qwen3:4b', 'llama3.2:3b'],
}) => {'reachable': reachable, 'models': models, 'detail': null};

void main() {
  late MockApiClient apiClient;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() => apiClient = MockApiClient());

  void stub({
    Map<String, dynamic>? settings,
    Map<String, dynamic>? health,
    Object? patchThrows,
  }) {
    when(
      () => apiClient.get('/settings'),
    ).thenAnswer((_) async => settings ?? _settingsJson());
    when(
      () => apiClient.get('/settings/inference/health'),
    ).thenAnswer((_) async => health ?? _healthJson());
    if (patchThrows != null) {
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenThrow(patchThrows);
    } else {
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenAnswer((_) async => settings ?? _settingsJson());
    }
  }

  Widget wrap({Locale locale = const Locale('fr')}) => ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(apiClient)],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Scrollable like the settings panel the card lives in, so a card taller
      // than the test viewport lays out as it does in the app.
      home: const Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 900, child: AiSettingsGroup()),
        ),
      ),
    ),
  );

  /// The colour of the status text's icon, which doubles its words.
  Color? statusColor(WidgetTester tester) => tester
      .widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('settingsAiStatusLabel')),
          matching: find.byType(Icon),
        ),
      )
      .color;

  /// The printed threshold, with the locale's no-break spaces made plain.
  String thresholdText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('settingsAiThresholdValue')))
      .data!
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ');

  group('connected', () {
    testWidgets(
      'says « Connecté » in green and the model count the probe returned',
      (tester) async {
        useDesktopSurface(tester);
        stub();

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(statusColor(tester), AppColors.dark.positive);
        expect(find.text('Connecté'), findsOneWidget);
        expect(find.text('· 3 modèles disponibles'), findsOneWidget);
      },
    );

    testWidgets(
      'the model field stays editable and lists what the engine offers',
      (tester) async {
        useDesktopSurface(tester);
        stub();

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settingsAiModelField')), findsOneWidget);
        expect(find.byKey(const Key('settingsAiModelReadOnly')), findsNothing);

        await tester.tap(find.byKey(const Key('settingsAiModelMenu')));
        await tester.pumpAndSettle();

        for (final tag in ['gemma3n:e4b', 'qwen3:4b', 'llama3.2:3b']) {
          expect(find.byKey(Key('settingsAiModelOption-$tag')), findsOneWidget);
        }
      },
    );

    testWidgets('picking a model from the list puts it in the field', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settingsAiModelMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsAiModelOption-qwen3:4b')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('settingsAiModelField')),
      );
      expect(field.controller!.text, 'qwen3:4b');
    });

    testWidgets('a tag can still be typed by hand', (tester) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settingsAiModelField')),
        'mistral:7b',
      );
      await tester.pump(settingsPatchDebounce * 2);
      await tester.pumpAndSettle();

      final body = verify(
        () => apiClient.patch('/settings', body: captureAny(named: 'body')),
      ).captured.last;
      expect(body, {'model_tag': 'mistral:7b'});
    });
  });

  group('no engine', () {
    testWidgets(
      'says no engine in amber, with the learn-more link and a disabled model field',
      (tester) async {
        useDesktopSurface(tester);
        stub(health: _healthJson(reachable: false, models: []));

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(statusColor(tester), AppColors.dark.warning);
        expect(
          find.text('Aucun moteur détecté à cette adresse.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('settingsAiLearnMore')), findsOneWidget);

        // Never an empty dropdown the user is trapped behind.
        expect(
          find.byKey(const Key('settingsAiModelReadOnly')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('settingsAiModelField')), findsNothing);
        expect(
          find.text('Moteur injoignable : aucun modèle à proposer.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the connected state offers no learn-more link', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiLearnMore')), findsNothing);
    });
  });

  group('privacy promise', () {
    testWidgets('is present with AI on', (tester) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiPrivacy')), findsOneWidget);
      expect(
        find.textContaining('Rien ne quitte votre machine.'),
        findsOneWidget,
      );
    });

    testWidgets('is still present with AI off', (tester) async {
      useDesktopSurface(tester);
      stub(settings: _settingsJson(aiEnabled: false));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiPrivacy')), findsOneWidget);
      expect(
        tester
            .widget<AppToggle>(find.byKey(const Key('settingsAiToggle')))
            .value,
        isFalse,
      );
      // Off, the engine rows are drawn at 45 % and out of reach, with no
      // status claiming anything about an engine nothing is using.
      expect(find.byKey(const Key('settingsAiStatus')), findsNothing);
      final engine = find.byKey(const Key('settingsAiEngineRow'));
      expect(
        find.ancestor(of: engine, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
    });
  });

  group('ollama', () {
    void stubOllama({required bool found}) {
      when(() => apiClient.get('/settings/inference/ollama')).thenAnswer(
        (_) async => {
          'found': found,
          'base_url': 'http://127.0.0.1:11434/v1',
          'models': found ? ['gemma4:e4b', 'qwen3:4b'] : <String>[],
        },
      );
    }

    testWidgets('a detected Ollama is offered when the address differs', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub(
        settings: _settingsJson(baseUrl: 'http://127.0.0.1:8080/v1'),
        health: _healthJson(reachable: false, models: []),
      );
      stubOllama(found: true);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(
        find.text('Ollama détecté sur cet ordinateur · 2 modèles installés'),
        findsOneWidget,
      );
    });

    testWidgets('using it rewrites the address field', (tester) async {
      useDesktopSurface(tester);
      stub(
        settings: _settingsJson(baseUrl: 'http://127.0.0.1:8080/v1'),
        health: _healthJson(reachable: false, models: []),
      );
      stubOllama(found: true);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenAnswer((_) async => _settingsJson());
      when(
        () => apiClient.get('/settings/inference/health'),
      ).thenAnswer((_) async => _healthJson());
      await tester.tap(find.byKey(const Key('settingsAiOllamaUse')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('settingsAiBaseUrlField')),
      );
      expect(field.controller!.text, 'http://127.0.0.1:11434/v1');
      expect(find.byKey(const Key('settingsAiOllamaPlate')), findsNothing);
    });

    testWidgets('nothing is offered when no Ollama answers', (tester) async {
      useDesktopSurface(tester);
      stub(
        settings: _settingsJson(baseUrl: 'http://127.0.0.1:8080/v1'),
        health: _healthJson(reachable: false, models: []),
      );
      stubOllama(found: false);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiOllamaPlate')), findsNothing);
    });
  });

  group('connection test', () {
    testWidgets('the button triggers a probe and reports its progress', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub(health: _healthJson(reachable: false, models: []));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(statusColor(tester), AppColors.dark.warning);

      // The engine came up between the mount probe and the explicit test.
      when(() => apiClient.get('/settings/inference/health')).thenAnswer((
        _,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return _healthJson();
      });

      await tester.tap(find.byKey(const Key('settingsAiTestButton')));
      await tester.pump();

      // Progress on the button itself, not a blocking overlay: the card is
      // still there behind it.
      expect(find.byKey(const Key('appButtonSpinner')), findsOneWidget);
      expect(find.text('Test en cours…'), findsOneWidget);
      expect(find.byKey(const Key('settingsAiCard')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(statusColor(tester), AppColors.dark.positive);
      expect(find.text('· 3 modèles disponibles'), findsOneWidget);
    });
  });

  group('engine address', () {
    testWidgets('a refused address explains why, on the field itself', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub(
        patchThrows: const ApiFailure(
          code: 'VALIDATION_ERROR',
          message: 'inference_base_url must point at a loopback host.',
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settingsAiBaseUrlField')),
        'http://ai.example.com/v1',
      );
      await tester.pump(settingsPatchDebounce * 2);
      await tester.pumpAndSettle();

      // Explains the rule, not just that the value was rejected.
      expect(
        find.textContaining("le moteur doit s'exécuter sur cet ordinateur"),
        findsOneWidget,
      );
      // Said in `negative`, under the engine line.
      final helper = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('settingsAiBaseUrlRejected')),
          matching: find.byType(Text),
        ),
      );
      expect(helper.style?.color, AppColors.dark.negative);
    });
  });

  group('threshold', () {
    testWidgets('is labelled as the percentage of the stored [0,1] value', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub(settings: _settingsJson(threshold: 0.65));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(thresholdText(tester), '65 %');
      expect(
        tester
            .widget<AppSlider>(
              find.byKey(const Key('settingsAiThresholdSlider')),
            )
            .value,
        65,
      );
    });

    testWidgets('dragging it stores the [0,1] real, not the percentage', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // A drag left of centre; the exact landing point is the slider's, so the
      // assertion is on the shape of what was stored.
      await tester.drag(
        find.byKey(const Key('settingsAiThresholdSlider')),
        const Offset(-60, 0),
      );
      await tester.pump(settingsPatchDebounce * 2);
      await tester.pumpAndSettle();

      final body =
          verify(
                () => apiClient.patch(
                  '/settings',
                  body: captureAny(named: 'body'),
                ),
              ).captured.last
              as Map<String, dynamic>;
      final stored = body['confidence_threshold'] as double;
      expect(stored, lessThan(0.8));
      expect(stored, inInclusiveRange(0, 1));
    });
  });

  group('locales', () {
    testWidgets('renders in English with no French left behind', (
      tester,
    ) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Local AI'), findsOneWidget);
      expect(find.text('AI categorization'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('· 3 models available'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Confidence threshold'), findsOneWidget);
      expect(thresholdText(tester), '80%');
      expect(
        find.textContaining('Nothing leaves your machine.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in French', (tester) async {
      useDesktopSurface(tester);
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('IA locale'), findsOneWidget);
      expect(find.text('Catégorisation par IA'), findsOneWidget);
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('Seuil de confiance'), findsOneWidget);
      expect(thresholdText(tester), '80 %');
    });
  });

  group('states', () {
    testWidgets('a failed load offers a retry instead of an empty card', (
      tester,
    ) async {
      useDesktopSurface(tester);
      when(
        () => apiClient.get('/settings'),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'down'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiError')), findsOneWidget);
      expect(find.byKey(const Key('settingsAiCard')), findsNothing);
    });

    testWidgets('the card renders a skeleton while it loads', (tester) async {
      useDesktopSurface(tester);
      final settings = Completer<Map<String, dynamic>>();
      when(() => apiClient.get('/settings')).thenAnswer((_) => settings.future);
      when(
        () => apiClient.get('/settings/inference/health'),
      ).thenAnswer((_) async => _healthJson());

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byKey(const Key('settingsAiLoading')), findsOneWidget);
      expect(find.byKey(const Key('settingsAiCard')), findsNothing);

      settings.complete(_settingsJson());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiCard')), findsOneWidget);
    });
  });
}
