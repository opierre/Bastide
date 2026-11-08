import 'dart:convert';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/monogram_avatar.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/categories/presentation/categories_screen.dart';
import 'package:bastide/features/rules/application/rule_packs_controller.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule_pack.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

class FakeRulePackFiles implements RulePackFiles {
  FakeRulePackFiles({this.pickedSource});

  final String? pickedSource;
  final saved = <String>[];

  @override
  Future<String?> pick() async => pickedSource;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    saved.add(contents);
    return 'C:/packs/rules.json';
  }
}

/// A 1×1 transparent PNG — an invented picture, not anyone's logo.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _linkedLogo = {
  'url': 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Example.svg',
  'license': 'CC0',
  'source': 'https://commons.wikimedia.org/wiki/File:Example.svg',
};

String _packSource({required bool withLogos}) => jsonEncode({
  'format_version': 1,
  'name': 'Commerces du quartier',
  'rules': [
    {
      'field': 'merchant',
      'type': 'contains',
      'pattern': 'CAFE DU PORT',
      'category_key': 'category.food.restaurants',
      if (withLogos) 'logo': {'data': _pngBase64},
    },
    {
      'field': 'merchant',
      'type': 'contains',
      'pattern': 'LIBRAIRIE DES QUAIS',
      'category_key': 'category.leisure.books',
      if (withLogos) 'logo': _linkedLogo,
    },
    {
      'field': 'merchant',
      'type': 'contains',
      'pattern': 'BOULANGERIE MARCEL',
      'category_key': 'category.food.groceries',
    },
  ],
});

Map<String, dynamic> _previewJson({required bool withLogos}) => {
  'name': 'Commerces du quartier',
  'total': 3,
  'new_count': 3,
  'duplicate_count': 0,
  'unresolved': <String>[],
  'would_match_count': 17,
  'samples': <Map<String, dynamic>>[],
  'logo_count': withLogos ? 2 : 0,
  'logo_download_count': withLogos ? 1 : 0,
};

Map<String, dynamic> _importJson({
  List<Map<String, dynamic>> failures = const [],
}) => {
  'created_count': 3,
  'skipped_count': 0,
  'unresolved': <String>[],
  'recategorized_count': 17,
  'logo_count': 1,
  'logo_skipped_count': 0,
  'logo_failures': failures,
};

Map<String, dynamic> _exportJson({
  bool withLogo = false,
  bool tooLarge = false,
}) => {
  'pack': {
    'format_version': 1,
    'name': 'Bastide rules',
    'rules': [
      {
        'field': 'merchant',
        'type': 'contains',
        'pattern': 'CAFE DU PORT',
        'category_key': 'category.food.restaurants',
        'enabled': true,
        if (withLogo) 'logo': {'data': _pngBase64},
      },
    ],
  },
  'omitted': <Map<String, dynamic>>[],
  'logo_count': withLogo ? 1 : 0,
  'logo_bytes': withLogo || tooLarge ? 68 : 0,
  'logos_too_large': tooLarge,
};

Widget _wrap(
  MockApiClient apiClient, {
  required FakeRulePackFiles files,
  required Locale locale,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      rulePackFilesProvider.overrideWithValue(files),
      rulesControllerProvider.overrideWith(() => FakeRulesController()),
      categoriesControllerProvider.overrideWith(
        () => FakeCategoriesController(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CategoriesScreen()),
    ),
  );
}

Future<void> _openMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('rulesViewSegment')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rulePackMenu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  late MockApiClient apiClient;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    when(
      () => apiClient.get('/rules/packs/builtin'),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
  });

  group('RulePackEntry logo', () {
    test('round-trips both logo forms unchanged', () {
      final pack = parseRulePack(_packSource(withLogos: true));
      final rules = pack.toJson()['rules'] as List<dynamic>;
      expect((rules[0] as Map)['logo'], {'data': _pngBase64});
      expect((rules[1] as Map)['logo'], _linkedLogo);
      expect((rules[2] as Map).containsKey('logo'), isFalse);
    });

    test('decodes an embedded logo, and gives up on bad base64', () {
      expect(RulePackLogo(const {'data': _pngBase64}).embeddedBytes, isNotNull);
      expect(RulePackLogo(const {'data': '***'}).embeddedBytes, isNull);
      expect(RulePackLogo(_linkedLogo).embeddedBytes, isNull);
      expect(RulePackLogo(_linkedLogo).isLinked, isTrue);
    });
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    final l10n = lookupAppLocalizations(locale);

    group('${locale.languageCode}:', () {
      Future<Map<String, dynamic>> importThroughSheet(
        WidgetTester tester, {
        required bool tickDownload,
        List<Map<String, dynamic>> failures = const [],
      }) async {
        when(
          () =>
              apiClient.post('/rules/packs/preview', body: any(named: 'body')),
        ).thenAnswer((_) async => _previewJson(withLogos: true));
        when(
          () => apiClient.post('/rules/packs/import', body: any(named: 'body')),
        ).thenAnswer((_) async => _importJson(failures: failures));

        final files = FakeRulePackFiles(
          pickedSource: _packSource(withLogos: true),
        );
        await tester.pumpWidget(_wrap(apiClient, files: files, locale: locale));
        await tester.pumpAndSettle();
        await _openMenuItem(tester, l10n.rulePackImportFile);

        if (tickDownload) {
          final checkbox = find.byKey(const Key('rulePackDownloadLogos'));
          await tester.ensureVisible(checkbox);
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
        await tester.pumpAndSettle();

        return verify(
              () => apiClient.post(
                '/rules/packs/import',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
      }

      testWidgets('the preview shows each rule behind its logo or monogram, '
          'the logo count and the download offer', (tester) async {
        when(
          () =>
              apiClient.post('/rules/packs/preview', body: any(named: 'body')),
        ).thenAnswer((_) async => _previewJson(withLogos: true));

        await tester.pumpWidget(
          _wrap(
            apiClient,
            files: FakeRulePackFiles(
              pickedSource: _packSource(withLogos: true),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await _openMenuItem(tester, l10n.rulePackImportFile);

        expect(find.byKey(const Key('rulePackRulesList')), findsOneWidget);
        expect(find.text('CAFE DU PORT'), findsOneWidget);
        // The embedded logo is drawn; the linked one (never downloaded by a
        // preview) and the logo-less rule fall back to the monogram.
        expect(find.byKey(const Key('rulePackLogoImage')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('rulePackRulesList')),
            matching: find.byType(MonogramAvatar),
          ),
          findsNWidgets(2),
        );

        expect(find.text(l10n.rulePackLogoCount), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('rulePackLogoCount')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.rulePackLogoDownload(1)), findsOneWidget);
        expect(find.text(l10n.rulePackLogoDownloadHelper), findsOneWidget);
        expect(l10n.rulePackLogoDownloadHelper, contains('Wikimedia Commons'));
      });

      testWidgets('a pack without logos offers no logo line or download', (
        tester,
      ) async {
        when(
          () =>
              apiClient.post('/rules/packs/preview', body: any(named: 'body')),
        ).thenAnswer((_) async => _previewJson(withLogos: false));

        await tester.pumpWidget(
          _wrap(
            apiClient,
            files: FakeRulePackFiles(
              pickedSource: _packSource(withLogos: false),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await _openMenuItem(tester, l10n.rulePackImportFile);

        expect(find.byKey(const Key('rulePackHeadline')), findsOneWidget);
        expect(find.byKey(const Key('rulePackLogoImage')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('rulePackRulesList')),
            matching: find.byType(MonogramAvatar),
          ),
          findsNWidgets(3),
        );
        expect(find.byKey(const Key('rulePackLogoCount')), findsNothing);
        expect(find.byKey(const Key('rulePackDownloadLogos')), findsNothing);
        expect(
          find.byKey(const Key('rulePackLogoDownloadHelper')),
          findsNothing,
        );
      });

      testWidgets('the download box is off by default', (tester) async {
        final body = await importThroughSheet(tester, tickDownload: false);
        expect(body['download_logos'], isFalse);
        // The pack goes back with its logos intact.
        final rules = (body['pack'] as Map<String, dynamic>)['rules'] as List;
        expect((rules[0] as Map)['logo'], {'data': _pngBase64});
        expect((rules[1] as Map)['logo'], _linkedLogo);
      });

      testWidgets('ticking the box asks the import to download the logos', (
        tester,
      ) async {
        final body = await importThroughSheet(tester, tickDownload: true);
        expect(body['download_logos'], isTrue);
      });

      testWidgets('failed logos are listed after a successful import', (
        tester,
      ) async {
        await importThroughSheet(
          tester,
          tickDownload: true,
          failures: [
            {
              'index': 1,
              'pattern': 'LIBRAIRIE DES QUAIS',
              'reason': 'download_failed',
            },
            {'index': 0, 'pattern': 'CAFE DU PORT', 'reason': 'invalid_image'},
          ],
        );

        // Still reported as an import that worked.
        expect(find.text(l10n.rulePackImportedTitle(3)), findsOneWidget);
        expect(find.text(l10n.rulePackLogoFailuresTitle(2)), findsOneWidget);
        expect(
          find.byKey(const Key('rulePackLogoFailuresNotice')),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.rulePackLogoFailureDownloadFailed('LIBRAIRIE DES QUAIS'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(l10n.rulePackLogoFailureInvalidImage('CAFE DU PORT')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('rulePackLogoFailuresClose')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.rulePackLogoFailuresTitle(2)), findsNothing);
      });

      testWidgets('an import with no failed logo shows no failure list', (
        tester,
      ) async {
        await importThroughSheet(tester, tickDownload: false);
        expect(find.text(l10n.rulePackImportedTitle(3)), findsOneWidget);
        expect(
          find.byKey(const Key('rulePackLogoFailuresNotice')),
          findsNothing,
        );
      });

      Future<List<Map<String, String>>> exportWithLogos(
        WidgetTester tester, {
        required bool tooLarge,
        FakeRulePackFiles? files,
      }) async {
        when(
          () =>
              apiClient.get('/rules/packs/export', query: any(named: 'query')),
        ).thenAnswer((invocation) async {
          final query =
              invocation.namedArguments[#query] as Map<String, String>;
          final withLogos = query['include_logos'] == 'true';
          return _exportJson(
            withLogo: withLogos && !tooLarge,
            tooLarge: withLogos && tooLarge,
          );
        });

        await tester.pumpWidget(
          _wrap(apiClient, files: files ?? FakeRulePackFiles(), locale: locale),
        );
        await tester.pumpAndSettle();
        await _openMenuItem(tester, l10n.rulePackExportAction);

        expect(find.text(l10n.rulePackExportIncludeLogos), findsOneWidget);
        await tester.tap(find.byKey(const Key('rulePackExportIncludeLogos')));
        await tester.pumpAndSettle();

        return verify(
          () => apiClient.get(
            '/rules/packs/export',
            query: captureAny(named: 'query'),
          ),
        ).captured.cast<Map<String, String>>();
      }

      testWidgets('the export option re-asks for the pack with its logos', (
        tester,
      ) async {
        final files = FakeRulePackFiles();
        final queries = await exportWithLogos(
          tester,
          tooLarge: false,
          files: files,
        );

        expect(queries.map((query) => query['include_logos']), [
          'false',
          'true',
        ]);
        expect(find.text(l10n.rulePackExportLogoCount(1)), findsOneWidget);
        expect(
          find.byKey(const Key('rulePackExportLogosTooLarge')),
          findsNothing,
        );
        // The preview shows a stand-in for the picture, never its base64...
        final preview = find.byKey(const Key('rulePackExportPreview'));
        expect(
          find.descendant(
            of: preview,
            matching: find.textContaining(l10n.rulePackExportLogoElided(1)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.textContaining(_pngBase64),
          ),
          findsNothing,
        );

        // ...while the saved file carries it.
        await tester.tap(find.byKey(const Key('rulePackExportSave')));
        await tester.pumpAndSettle();
        expect(files.saved.single, contains(_pngBase64));
      });

      testWidgets('logos too large for a pack are left out, and said so', (
        tester,
      ) async {
        await exportWithLogos(tester, tooLarge: true);

        expect(
          find.byKey(const Key('rulePackExportLogosTooLarge')),
          findsOneWidget,
        );
        expect(find.text(l10n.rulePackExportLogosTooLarge), findsOneWidget);
        expect(find.byKey(const Key('rulePackExportLogoCount')), findsNothing);
        // The rules are all still there.
        expect(
          find.descendant(
            of: find.byKey(const Key('rulePackExportPreview')),
            matching: find.textContaining('CAFE DU PORT'),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
