import 'package:finstride/core/api/api_client.dart';
import 'package:finstride/core/api/api_client_provider.dart';
import 'package:finstride/features/settings/application/settings_controller.dart';
import 'package:finstride/features/settings/domain/user_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Map<String, dynamic> _settingsJson({
  bool aiEnabled = false,
  String baseUrl = 'http://127.0.0.1:11434/v1',
  String? modelTag,
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
  String? detail,
}) => {'reachable': reachable, 'models': models, 'detail': detail};

void main() {
  late MockApiClient apiClient;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
  });

  void stubSettings(Map<String, dynamic> json) {
    when(() => apiClient.get('/settings')).thenAnswer((_) async => json);
  }

  void stubHealth(Map<String, dynamic> json) {
    when(
      () => apiClient.get('/settings/inference/health'),
    ).thenAnswer((_) async => json);
  }

  void stubPatch(Map<String, dynamic> json) {
    when(
      () => apiClient.patch('/settings', body: any(named: 'body')),
    ).thenAnswer((_) async => json);
  }

  Future<SettingsState> load() =>
      container.read(settingsControllerProvider.future);

  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  group('load', () {
    test('reads the defaults and reports the link as disabled', () async {
      stubSettings(_settingsJson());

      final state = await load();

      expect(state.settings.aiEnabled, isFalse);
      expect(state.settings.inferenceBaseUrl, 'http://127.0.0.1:11434/v1');
      expect(state.settings.modelTag, isNull);
      expect(state.settings.confidenceThreshold, 0.8);
      expect(state.connection, InferenceConnection.disabled);
      expect(state.models, isEmpty);
      // Nothing was dialed: the user has not opted in, so there is no runtime
      // to ask about.
      verifyNever(() => apiClient.get('/settings/inference/health'));
    });

    test('probes on mount once the user has opted in', () async {
      stubSettings(_settingsJson(aiEnabled: true, modelTag: 'gemma3n:e4b'));
      stubHealth(_healthJson());

      final state = await load();

      expect(state.connection, InferenceConnection.reachable);
      expect(state.models, ['gemma3n:e4b', 'qwen3:4b', 'llama3.2:3b']);
    });

    test(
      'a runtime that does not answer is unreachable, not an error',
      () async {
        stubSettings(_settingsJson(aiEnabled: true));
        stubHealth(
          _healthJson(
            reachable: false,
            models: [],
            detail: 'connection refused',
          ),
        );

        final state = await load();

        expect(state.connection, InferenceConnection.unreachable);
        expect(state.models, isEmpty);
      },
    );

    test('a probe that cannot even be sent reads as unreachable', () async {
      stubSettings(_settingsJson(aiEnabled: true));
      when(
        () => apiClient.get('/settings/inference/health'),
      ).thenThrow(const ApiFailure(code: 'UNKNOWN_ERROR', message: 'boom'));

      final state = await load();

      expect(state.connection, InferenceConnection.unreachable);
    });
  });

  group('patch debounce', () {
    test('coalesces edits inside the window into one request', () async {
      stubSettings(_settingsJson());
      stubPatch(_settingsJson(modelTag: 'qwen3:4b', threshold: 0.65));
      await load();

      controller().setThresholdPercent(70);
      controller().setThresholdPercent(65);
      controller().setModelTag('qwen3:4b');

      verifyNever(() => apiClient.patch('/settings', body: any(named: 'body')));

      await Future<void>.delayed(settingsPatchDebounce * 2);

      final body = verify(
        () => apiClient.patch('/settings', body: captureAny(named: 'body')),
      ).captured.single;
      expect(body, {'model_tag': 'qwen3:4b', 'confidence_threshold': 0.65});
    });

    test('shows the typed value immediately, before the patch fires', () async {
      stubSettings(_settingsJson());
      stubPatch(_settingsJson(baseUrl: 'http://localhost:8080/v1'));
      await load();

      controller().setBaseUrl('http://localhost:8080/v1');

      expect(
        container
            .read(settingsControllerProvider)
            .value!
            .settings
            .inferenceBaseUrl,
        'http://localhost:8080/v1',
      );
    });

    test('a rejected address is reported against that field', () async {
      stubSettings(_settingsJson());
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'VALIDATION_ERROR', message: 'not loopback'),
      );
      await load();

      controller().setBaseUrl('http://example.com/v1');
      await Future<void>.delayed(settingsPatchDebounce * 2);

      final state = container.read(settingsControllerProvider).value!;
      expect(state.baseUrlError, isA<ApiFailure>());
      // The refused value stays on screen — it is what the user has to correct.
      expect(state.settings.inferenceBaseUrl, 'http://example.com/v1');
    });

    test('editing the address again clears the previous rejection', () async {
      stubSettings(_settingsJson());
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'VALIDATION_ERROR', message: 'not loopback'),
      );
      await load();

      controller().setBaseUrl('http://example.com/v1');
      await Future<void>.delayed(settingsPatchDebounce * 2);
      expect(
        container.read(settingsControllerProvider).value!.baseUrlError,
        isNotNull,
      );

      controller().setBaseUrl('http://127.0.0.1:11434/v1');

      expect(
        container.read(settingsControllerProvider).value!.baseUrlError,
        isNull,
      );
    });

    test('a threshold rejection does not land on the address field', () async {
      stubSettings(_settingsJson());
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenThrow(
        const ApiFailure(code: 'VALIDATION_ERROR', message: 'out of range'),
      );
      await load();

      controller().setThresholdPercent(50);
      await Future<void>.delayed(settingsPatchDebounce * 2);

      expect(
        container.read(settingsControllerProvider).value!.baseUrlError,
        isNull,
      );
    });
  });

  group('threshold conversion', () {
    test('the [0,1] real is shown as a whole percent', () async {
      stubSettings(_settingsJson(threshold: 0.65));

      expect((await load()).thresholdPercent, 65);
    });

    test('a percent off the slider is stored as the [0,1] real', () async {
      stubSettings(_settingsJson());
      stubPatch(_settingsJson(threshold: 0.45));
      await load();

      controller().setThresholdPercent(45);
      await Future<void>.delayed(settingsPatchDebounce * 2);

      final body =
          verify(
                () => apiClient.patch(
                  '/settings',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['confidence_threshold'], 0.45);
    });

    test(
      'a threshold round-trips through both conversions unchanged',
      () async {
        stubSettings(_settingsJson(threshold: 0.8));
        await load();

        for (final percent in [0, 33, 50, 80, 100]) {
          final settings = UserSettings(
            aiEnabled: true,
            inferenceBaseUrl: 'http://127.0.0.1:11434/v1',
            modelTag: null,
            confidenceThreshold: UserSettings.thresholdFromPercent(percent),
          );
          expect(settings.confidenceThresholdPercent, percent);
          expect(settings.confidenceThreshold, inInclusiveRange(0, 1));
        }
      },
    );
  });

  group('opting in and out', () {
    test('turning it on patches at once and probes the runtime', () async {
      stubSettings(_settingsJson());
      stubPatch(_settingsJson(aiEnabled: true));
      stubHealth(_healthJson());
      await load();

      await controller().setAiEnabled(true);

      final state = container.read(settingsControllerProvider).value!;
      expect(state.settings.aiEnabled, isTrue);
      expect(state.connection, InferenceConnection.reachable);
      expect(state.models, isNotEmpty);
    });

    test(
      'turning it off drops the connection rather than keeping it green',
      () async {
        stubSettings(_settingsJson(aiEnabled: true));
        stubHealth(_healthJson());
        stubPatch(_settingsJson());
        final loaded = await load();
        expect(loaded.connection, InferenceConnection.reachable);

        await controller().setAiEnabled(false);

        final state = container.read(settingsControllerProvider).value!;
        expect(state.settings.aiEnabled, isFalse);
        expect(state.connection, InferenceConnection.disabled);
        expect(state.models, isEmpty);
      },
    );
  });

  group('explicit test button', () {
    test('flushes a pending edit first, so it probes what was typed', () async {
      stubSettings(_settingsJson(aiEnabled: true));
      stubHealth(_healthJson(reachable: false, models: []));
      stubPatch(
        _settingsJson(aiEnabled: true, baseUrl: 'http://127.0.0.1:8080/v1'),
      );
      await load();

      controller().setBaseUrl('http://127.0.0.1:8080/v1');
      stubHealth(_healthJson());
      await controller().probe();

      verify(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).called(1);
      expect(
        container.read(settingsControllerProvider).value!.connection,
        InferenceConnection.reachable,
      );
    });

    test('probing while opted out still reports what answered', () async {
      stubSettings(_settingsJson());
      stubHealth(_healthJson());
      await load();

      await controller().probe();

      final state = container.read(settingsControllerProvider).value!;
      expect(state.connection, InferenceConnection.reachable);
      expect(state.models, isNotEmpty);
    });
  });
}
