import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/core/widgets/monogram_avatar.dart';
import 'package:bastide/features/categories/application/categories_controller.dart';
import 'package:bastide/features/rules/application/rules_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/features/rules/presentation/rule_editor_modal.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_categories_controller.dart';
import '../../support/fake_rules_controller.dart';

class _MockApiClient extends Mock implements ApiClient {}

// A 1×1 transparent PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Map<String, dynamic> _ruleJson({bool logo = false}) => {
  'id': 'r1',
  'priority': 1,
  'match_field': 'description_clean',
  'match_type': 'contains',
  'pattern': 'STREAMFLIX',
  'category_id': 'leisure',
  'enabled': true,
  'logo_updated_at': logo ? '2026-05-14T10:00:00Z' : null,
  'created_at': '2026-01-01T00:00:00Z',
};

Widget _wrap(
  _MockApiClient api, {
  Rule? rule,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      rulesControllerProvider.overrideWith(
        () => FakeRulesController(initialRules: [?rule]),
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

Future<void> _open(WidgetTester tester) async {
  // A desktop window: the editor is taller than the default test surface.
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockApiClient api;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    api = _MockApiClient();
    when(
      () => api.post('/rules/preview', body: any(named: 'body')),
    ).thenAnswer((_) async => {'match_count': 0, 'samples': <dynamic>[]});
    when(
      () => api.getBytes('/rules/r1/logo'),
    ).thenAnswer((_) async => ApiBytesResponse(bytes: _png, headers: {}));
  });

  for (final (locale, saveFirst, choose) in [
    (
      const Locale('fr'),
      'Enregistrez la règle pour pouvoir lui ajouter un logo.',
      'Choisir une image…',
    ),
    (
      const Locale('en'),
      'Save the rule to add a logo to it.',
      'Choose a picture…',
    ),
  ]) {
    testWidgets('a new rule is told to save first (${locale.languageCode})', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(api, locale: locale));
      await _open(tester);

      expect(find.text(saveFirst), findsOneWidget);
      expect(find.byKey(const Key('ruleFormLogoChoose')), findsNothing);
    });

    testWidgets(
      'a saved rule offers to choose a logo (${locale.languageCode})',
      (tester) async {
        await tester.pumpWidget(
          _wrap(api, rule: Rule.fromJson(_ruleJson()), locale: locale),
        );
        await _open(tester);

        expect(find.text(choose), findsOneWidget);
        expect(find.byKey(const Key('ruleFormLogoRemove')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('ruleFormLogoPreview')),
            matching: find.byType(MonogramAvatar),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'a rule with a logo previews it, and removing it brings the monogram back',
    (tester) async {
      when(
        () => api.delete('/rules/r1/logo'),
      ).thenAnswer((_) async => _ruleJson());
      await tester.pumpWidget(
        _wrap(api, rule: Rule.fromJson(_ruleJson(logo: true))),
      );
      await _open(tester);

      expect(find.byKey(const Key('institutionAvatarLogo')), findsOneWidget);
      expect(find.text('Remplacer…'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ruleFormLogoRemove')));
      await tester.pumpAndSettle();

      verify(() => api.delete('/rules/r1/logo')).called(1);
      expect(find.byKey(const Key('institutionAvatarLogo')), findsNothing);
      expect(find.byKey(const Key('ruleFormLogoRemove')), findsNothing);
    },
  );

  testWidgets(
    'clicking the logo preview opens it larger, and Escape closes it',
    (tester) async {
      await tester.pumpWidget(
        _wrap(api, rule: Rule.fromJson(_ruleJson(logo: true))),
      );
      await _open(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('ruleFormLogoPreview')),
          matching: find.byKey(const Key('logoZoomTarget')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logoZoomDialog')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logoZoomDialog')), findsNothing);
      // Escape closed the enlarged logo only, not the editor under it.
      expect(find.byKey(const Key('ruleFormLogoPreview')), findsOneWidget);
    },
  );

  testWidgets('the monogram preview is not clickable', (tester) async {
    await tester.pumpWidget(_wrap(api, rule: Rule.fromJson(_ruleJson())));
    await _open(tester);

    expect(find.byKey(const Key('logoZoomTarget')), findsNothing);
  });
}
