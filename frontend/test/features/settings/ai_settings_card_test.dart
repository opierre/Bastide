import 'dart:async';

import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/core/theme/app_theme.dart';
import 'package:finstride/core/theme/tokens.dart';
import 'package:finstride/core/widgets/app_slider.dart';
import 'package:finstride/core/widgets/app_toggle.dart';
import 'package:finstride/features/settings/application/settings_controller.dart';
import 'package:finstride/features/settings/presentation/ai_settings_card.dart';
import 'package:finstride/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox(width: 640, child: AiSettingsCard())),
    ),
  );

  Color dotColor(WidgetTester tester) {
    final box = tester.widget<Container>(
      find.byKey(const Key('settingsAiStatusDot')),
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  group('connected', () {
    testWidgets('shows a green dot and the model count the probe returned', (
      tester,
    ) async {
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(dotColor(tester), AppColors.positive);
      expect(find.text('Connecté — 3 modèles disponibles'), findsOneWidget);
    });

    testWidgets(
      'the model field stays editable and lists what the engine offers',
      (tester) async {
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
      'shows an amber dot, the learn-more link, and a dashed model field',
      (tester) async {
        stub(health: _healthJson(reachable: false, models: []));

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(dotColor(tester), AppColors.warning);
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
        expect(find.text('Aucun modèle — moteur injoignable.'), findsOneWidget);
      },
    );

    testWidgets('the connected state offers no learn-more link', (
      tester,
    ) async {
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiLearnMore')), findsNothing);
    });
  });

  group('privacy callout', () {
    testWidgets('is present with AI on', (tester) async {
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
      expect(find.text('Catégorisation par IA désactivée.'), findsOneWidget);
    });
  });

  group('connection test', () {
    testWidgets('the button triggers a probe and reports its progress', (
      tester,
    ) async {
      stub(health: _healthJson(reachable: false, models: []));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(dotColor(tester), AppColors.warning);

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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('settingsAiCard')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(dotColor(tester), AppColors.positive);
      expect(find.text('Connecté — 3 modèles disponibles'), findsOneWidget);
    });
  });

  group('engine address', () {
    testWidgets('a refused address explains why, on the field itself', (
      tester,
    ) async {
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
      // The helper it replaces is gone, so the fix is the only line under the
      // field.
      expect(
        find.text('Adresse locale uniquement — 127.0.0.1 ou localhost.'),
        findsNothing,
      );
    });
  });

  group('threshold', () {
    testWidgets('is labelled as the percentage of the stored [0,1] value', (
      tester,
    ) async {
      stub(settings: _settingsJson(threshold: 0.65));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Seuil de confiance — 65 %'), findsOneWidget);
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
      stub();

      await tester.pumpWidget(wrap(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Local AI'), findsOneWidget);
      expect(find.text('Enable AI categorization'), findsOneWidget);
      expect(find.text('Connected — 3 models available'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Confidence threshold — 80%'), findsOneWidget);
      expect(
        find.textContaining('Nothing leaves your machine.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in French', (tester) async {
      stub();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('IA locale'), findsOneWidget);
      expect(find.text('Activer la catégorisation par IA'), findsOneWidget);
      expect(find.text('Tester la connexion'), findsOneWidget);
      expect(find.text('Seuil de confiance — 80 %'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('a failed load offers a retry instead of an empty card', (
      tester,
    ) async {
      when(
        () => apiClient.get('/settings'),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'down'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsAiError')), findsOneWidget);
      expect(find.byKey(const Key('settingsAiCard')), findsNothing);
    });

    testWidgets('the card renders a skeleton while it loads', (tester) async {
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
