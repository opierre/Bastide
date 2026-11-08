import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/pictures/picture_download.dart';
import 'package:bastide/core/pictures/pictures.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/rules/application/rule_logo_url_controller.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/features/rules/presentation/rule_editor_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockImaging extends Mock implements PictureImaging {}

class _MockApiClient extends Mock implements ApiClient {}

class _FakeImage extends Fake implements ui.Image {}

class _FakeRequest extends Fake implements http.BaseRequest {}

const _address = 'https://logos.example.test/streamflix.png';

final _bytes = Uint8List.fromList(List.filled(64, 7));

/// An answer to the download, streamed in [chunks] chunks.
http.StreamedResponse _response(
  List<int> body, {
  int status = 200,
  int? contentLength,
  int chunks = 1,
}) {
  final size = (body.length / chunks).ceil();
  return http.StreamedResponse(
    Stream.fromIterable([
      for (var i = 0; i < body.length; i += size)
        body.sublist(i, (i + size).clamp(0, body.length)),
    ]),
    status,
    contentLength: contentLength,
  );
}

void main() {
  late _MockHttpClient client;
  late _MockImaging imaging;

  setUpAll(() {
    registerFallbackValue(_FakeRequest());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockHttpClient();
    imaging = _MockImaging();
  });

  group('RuleLogoUrlController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          pictureHttpClientProvider.overrideWithValue(client),
          pictureImagingProvider.overrideWithValue(imaging),
        ],
      );
      addTearDown(container.dispose);
    });

    RuleLogoUrlController controller() {
      // autoDispose: keep it alive across the awaits of a test.
      container.listen(ruleLogoUrlControllerProvider, (_, _) {});
      return container.read(ruleLogoUrlControllerProvider.notifier);
    }

    PictureDownloadFailure? failure() =>
        container.read(ruleLogoUrlControllerProvider).failure;

    test('downloads a picture and decodes it for the crop step', () async {
      final image = _FakeImage();
      when(() => client.send(any())).thenAnswer(
        (_) async => _response(_bytes, contentLength: _bytes.length, chunks: 4),
      );
      when(() => imaging.decode(any())).thenAnswer((_) async => image);

      final result = await controller().fetch('  $_address ');

      expect(result, same(image));
      expect(failure(), isNull);
      final request =
          verify(() => client.send(captureAny())).captured.single
              as http.BaseRequest;
      expect(request.method, 'GET');
      expect(request.url, Uri.parse(_address));
      expect(
        verify(() => imaging.decode(captureAny())).captured.single,
        _bytes,
      );
    });

    test('refuses a download that is not a picture', () async {
      when(() => client.send(any())).thenAnswer((_) async => _response(_bytes));
      when(() => imaging.decode(any())).thenThrow(Exception('not an image'));

      expect(await controller().fetch(_address), isNull);
      expect(failure(), PictureDownloadFailure.notAPicture);
    });

    test('refuses an announced oversized file without reading it', () async {
      when(() => client.send(any())).thenAnswer(
        (_) async =>
            _response(_bytes, contentLength: maxPictureUploadBytes + 1),
      );

      expect(await controller().fetch(_address), isNull);
      expect(failure(), PictureDownloadFailure.tooLarge);
      verifyNever(() => imaging.decode(any()));
    });

    test('stops an oversized file that announced no size at the cap', () async {
      final body = Uint8List(maxPictureUploadBytes + 1);
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _response(body, chunks: 8));

      expect(await controller().fetch(_address), isNull);
      expect(failure(), PictureDownloadFailure.tooLarge);
      verifyNever(() => imaging.decode(any()));
    });

    test('reports a network error as unreachable', () async {
      when(
        () => client.send(any()),
      ).thenThrow(const SocketException('connection refused'));

      expect(await controller().fetch(_address), isNull);
      expect(failure(), PictureDownloadFailure.unreachable);
    });

    test('reports an error status as unreachable', () async {
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _response(_bytes, status: 404));

      expect(await controller().fetch(_address), isNull);
      expect(failure(), PictureDownloadFailure.unreachable);
      verifyNever(() => imaging.decode(any()));
    });

    for (final address in [
      '',
      'logos.example.test/streamflix.png',
      'ftp://logos.example.test/streamflix.png',
      'file:///tmp/streamflix.png',
      'https://',
    ]) {
      test('refuses "$address" without a network call', () async {
        expect(await controller().fetch(address), isNull);
        expect(failure(), PictureDownloadFailure.invalidAddress);
        verifyNever(() => client.send(any()));
      });
    }
  });

  testWidgets('gives up on a download slower than the timeout', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pictureHttpClientProvider.overrideWithValue(client),
        pictureImagingProvider.overrideWithValue(imaging),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ruleLogoUrlControllerProvider, (_, _) {});
    when(
      () => client.send(any()),
    ).thenAnswer((_) => Completer<http.StreamedResponse>().future);

    final fetch = container
        .read(ruleLogoUrlControllerProvider.notifier)
        .fetch(_address);
    await tester.pump(pictureDownloadTimeout + const Duration(seconds: 1));

    expect(await fetch, isNull);
    expect(
      container.read(ruleLogoUrlControllerProvider).failure,
      PictureDownloadFailure.unreachable,
    );
  });

  group('rule editor', () {
    late _MockApiClient api;

    setUp(() {
      api = _MockApiClient();
      when(
        () => api.post('/rules/preview', body: any(named: 'body')),
      ).thenAnswer((_) async => {'match_count': 0, 'samples': <dynamic>[]});
    });

    Widget wrap(Locale locale) {
      final rule = Rule.fromJson({
        'id': 'r1',
        'priority': 1,
        'match_field': 'description_clean',
        'match_type': 'contains',
        'pattern': 'STREAMFLIX',
        'category_id': 'leisure',
        'enabled': true,
        'logo_updated_at': null,
        'created_at': '2026-01-01T00:00:00Z',
      });
      return ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          pictureHttpClientProvider.overrideWithValue(client),
          pictureImagingProvider.overrideWithValue(imaging),
          rulesControllerProvider.overrideWith(
            () => FakeRulesController(initialRules: [rule]),
          ),
          categoriesControllerProvider.overrideWith(
            () => FakeCategoriesController(
              initialCategories: [
                testCategory(id: 'leisure', name: 'category.leisure'),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          theme: appDarkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRuleEditor(context, initial: rule),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openUrlDialog(WidgetTester tester, Locale locale) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(locale));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ruleFormLogoFromUrl')));
      await tester.pumpAndSettle();
    }

    for (final (locale, button, error) in [
      (
        const Locale('fr'),
        'Depuis une adresse…',
        'Cette adresse ne mène pas à une image.',
      ),
      (
        const Locale('en'),
        'From an address…',
        "This address doesn't lead to a picture.",
      ),
    ]) {
      testWidgets(
        'downloads only on confirm, and shows a refusal in the dialog '
        '(${locale.languageCode})',
        (tester) async {
          when(
            () => client.send(any()),
          ).thenAnswer((_) async => _response(_bytes));
          when(
            () => imaging.decode(any()),
          ).thenThrow(Exception('not an image'));
          await openUrlDialog(tester, locale);

          expect(find.text(button), findsOneWidget);
          await tester.enterText(
            find.byKey(const Key('ruleLogoUrlField')),
            _address,
          );
          await tester.pump();
          verifyNever(() => client.send(any()));

          await tester.tap(find.byKey(const Key('ruleLogoUrlFetch')));
          await tester.pumpAndSettle();

          verify(() => client.send(any())).called(1);
          expect(find.text(error), findsOneWidget);
          expect(find.byKey(const Key('ruleLogoUrlField')), findsOneWidget);
        },
      );
    }

    testWidgets('a downloaded picture goes on to the crop step', (
      tester,
    ) async {
      final image = await tester.runAsync(() => createTestImage(width: 40));
      when(() => client.send(any())).thenAnswer((_) async => _response(_bytes));
      when(() => imaging.decode(any())).thenAnswer((_) async => image!);
      await openUrlDialog(tester, const Locale('fr'));

      await tester.enterText(
        find.byKey(const Key('ruleLogoUrlField')),
        _address,
      );
      await tester.tap(find.byKey(const Key('ruleLogoUrlFetch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ruleLogoUrlField')), findsNothing);
      expect(find.byKey(const Key('pictureCropViewport')), findsOneWidget);
      expect(find.text('Recadrer le logo'), findsOneWidget);
    });
  });
}
