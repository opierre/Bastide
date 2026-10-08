import 'dart:convert';

import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
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

/// A `RulePackFiles` double: hands back a canned document, and records what an
/// export would have written instead of touching the filesystem.
class FakeRulePackFiles implements RulePackFiles {
  FakeRulePackFiles({this.pickedSource, this.savePath = 'C:/packs/rules.json'});

  final String? pickedSource;
  final String? savePath;

  final saved = <({String name, String contents})>[];

  @override
  Future<String?> pick() async => pickedSource;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    saved.add((name: suggestedName, contents: contents));
    return savePath;
  }
}

String _packSource({
  int formatVersion = 1,
  String type = 'contains',
  String name = 'Commerçants français',
}) => jsonEncode({
  'format_version': formatVersion,
  'name': name,
  'locale': 'fr',
  'rules': [
    {
      'field': 'merchant',
      'type': type,
      'pattern': 'CARREFOUR',
      'category_key': 'category.food.groceries',
    },
  ],
});

Map<String, dynamic> _previewJson({
  int total = 12,
  int newCount = 10,
  int duplicateCount = 2,
  List<String> unresolved = const [],
  int wouldMatch = 342,
}) => {
  'name': 'Commerçants français',
  'total': total,
  'new_count': newCount,
  'duplicate_count': duplicateCount,
  'unresolved': unresolved,
  'would_match_count': wouldMatch,
  'samples': [
    {
      'id': 't1',
      'description_clean': 'CB CARREFOUR PARIS 15',
      'booked_date': '2026-05-14',
    },
  ],
};

Map<String, dynamic> _exportJson({
  List<Map<String, dynamic>> omitted = const [],
}) => {
  'pack': {
    'format_version': 1,
    'name': 'Bastide rules',
    'locale': 'fr',
    'rules': [
      {
        'field': 'merchant',
        'type': 'contains',
        'pattern': 'VIR SALAIRE DUPONT',
        'category_key': 'category.income.salary',
        'enabled': true,
      },
    ],
  },
  'omitted': omitted,
};

Widget _wrap(
  MockApiClient apiClient, {
  required FakeRulePackFiles files,
  FakeRulesController? rules,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
      rulePackFilesProvider.overrideWithValue(files),
      rulesControllerProvider.overrideWith(
        () => rules ?? FakeRulesController(),
      ),
      categoriesControllerProvider.overrideWith(
        () => FakeCategoriesController(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: appDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CategoriesScreen()),
    ),
  );
}

Future<void> _openRules(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rulesViewSegment')));
  await tester.pumpAndSettle();
}

void main() {
  late MockApiClient apiClient;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    apiClient = MockApiClient();
    when(() => apiClient.get('/rules/packs/builtin')).thenAnswer(
      (_) async => [
        {
          'id': 'fr-starter',
          'name': 'Commerçants français',
          'locale': 'fr',
          'rule_count': 12,
        },
      ],
    );
  });

  group('parseRulePack', () {
    test('accepts a v1 pack', () {
      final pack = parseRulePack(_packSource());
      expect(pack.name, 'Commerçants français');
      expect(pack.rules.single.pattern, 'CARREFOUR');
    });

    test('refuses an unsupported format_version, naming that reason', () {
      expect(
        () => parseRulePack(_packSource(formatVersion: 2)),
        throwsA(
          isA<RulePackRejected>().having(
            (error) => error.reason,
            'reason',
            RulePackRefusal.unsupportedVersion,
          ),
        ),
      );
    });

    test('refuses a pack carrying a regex rule', () {
      expect(
        () => parseRulePack(_packSource(type: 'regex')),
        throwsA(
          isA<RulePackRejected>().having(
            (error) => error.reason,
            'reason',
            RulePackRefusal.regexNotAllowed,
          ),
        ),
      );
    });

    test('refuses a file that is not JSON', () {
      expect(
        () => parseRulePack('not a pack'),
        throwsA(
          isA<RulePackRejected>().having(
            (error) => error.reason,
            'reason',
            RulePackRefusal.malformed,
          ),
        ),
      );
    });
  });

  testWidgets(
    'importing a file always shows the report before writing anything',
    (tester) async {
      when(
        () => apiClient.post('/rules/packs/preview', body: any(named: 'body')),
      ).thenAnswer((_) async => _previewJson());
      when(
        () => apiClient.post('/rules/packs/import', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {
          'created_count': 10,
          'skipped_count': 2,
          'unresolved': <String>[],
          'recategorized_count': 342,
        },
      );

      final files = FakeRulePackFiles(pickedSource: _packSource());
      await tester.pumpWidget(_wrap(apiClient, files: files));
      await tester.pumpAndSettle();
      await _openRules(tester);

      await tester.tap(find.byKey(const Key('rulePackMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer un fichier…'));
      await tester.pumpAndSettle();

      // Nothing written yet — the report comes first, always.
      verifyNever(
        () => apiClient.post('/rules/packs/import', body: any(named: 'body')),
      );
      expect(
        find.text(
          'Ce pack catégoriserait 342 de vos transactions non catégorisées.',
        ),
        findsOneWidget,
      );
      expect(find.text('10'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('rulePackImportConfirm')));
      await tester.pumpAndSettle();

      verify(
        () => apiClient.post('/rules/packs/import', body: any(named: 'body')),
      ).called(1);
      expect(find.text('10 règles importées'), findsOneWidget);
    },
  );

  testWidgets('a refused pack explains why, and never reaches the backend', (
    tester,
  ) async {
    final files = FakeRulePackFiles(pickedSource: _packSource(type: 'regex'));
    await tester.pumpWidget(_wrap(apiClient, files: files));
    await tester.pumpAndSettle();
    await _openRules(tester);

    await tester.tap(find.byKey(const Key('rulePackMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer un fichier…'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rulePackRefusal')), findsOneWidget);
    expect(find.textContaining('regex'), findsWidgets);
    verifyNever(
      () => apiClient.post('/rules/packs/preview', body: any(named: 'body')),
    );
  });

  testWidgets('an unsupported version explains the version this build reads', (
    tester,
  ) async {
    final files = FakeRulePackFiles(
      pickedSource: _packSource(formatVersion: 7),
    );
    await tester.pumpWidget(_wrap(apiClient, files: files));
    await tester.pumpAndSettle();
    await _openRules(tester);

    await tester.tap(find.byKey(const Key('rulePackMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer un fichier…'));
    await tester.pumpAndSettle();

    expect(find.textContaining('la version 1'), findsOneWidget);
  });

  testWidgets(
    'export shows the pack contents and the omission report before saving',
    (tester) async {
      when(
        () => apiClient.get('/rules/packs/export', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => _exportJson(
          omitted: [
            {'rule_id': 'r9', 'pattern': '^CB .*AMAZON', 'reason': 'regex'},
          ],
        ),
      );

      final files = FakeRulePackFiles();
      await tester.pumpWidget(_wrap(apiClient, files: files));
      await tester.pumpAndSettle();
      await _openRules(tester);

      await tester.tap(find.byKey(const Key('rulePackMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exporter mes règles…'));
      await tester.pumpAndSettle();

      // The contents, verbatim — including the pattern that carries a name.
      expect(find.byKey(const Key('rulePackExportPreview')), findsOneWidget);
      // Scoped to the preview: the privacy notice quotes the same label as its
      // example, which is the point of the example but not what this asserts.
      expect(
        find.descendant(
          of: find.byKey(const Key('rulePackExportPreview')),
          matching: find.textContaining('VIR SALAIRE DUPONT'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('rulePackPrivacyNotice')), findsOneWidget);
      expect(find.byKey(const Key('rulePackOmitted-r9')), findsOneWidget);
      expect(files.saved, isEmpty);

      await tester.tap(find.byKey(const Key('rulePackExportSave')));
      await tester.pumpAndSettle();

      expect(files.saved, hasLength(1));
      expect(files.saved.single.name, 'Bastide-rules.json');
      expect(files.saved.single.contents, contains('VIR SALAIRE DUPONT'));
    },
  );

  testWidgets('the rules empty state offers the bundled French pack', (
    tester,
  ) async {
    when(
      () => apiClient.post('/rules/packs/preview', body: any(named: 'body')),
    ).thenAnswer((_) async => _previewJson());

    await tester.pumpWidget(_wrap(apiClient, files: FakeRulePackFiles()));
    await tester.pumpAndSettle();
    await _openRules(tester);

    expect(find.byKey(const Key('rulesEmptyState')), findsOneWidget);
    final offer = find.byKey(const Key('emptyStateBuiltinPackButton'));
    expect(offer, findsOneWidget);
    expect(find.textContaining('Commerçants français'), findsOneWidget);

    // The empty state scrolls in a short window (see `CenteredStatePane`), and
    // the offer sits below the CTA.
    await tester.ensureVisible(offer);
    await tester.pumpAndSettle();
    await tester.tap(offer);
    await tester.pumpAndSettle();

    // Straight to the same confirmation sheet — no file, no shortcut past it.
    expect(find.byKey(const Key('rulePackHeadline')), findsOneWidget);
    final body =
        verify(
              () => apiClient.post(
                '/rules/packs/preview',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['builtin_id'], 'fr-starter');
  });
}
