import 'package:bastide/core/theme/tokens.dart';
import 'package:bastide/core/widgets/app_modal.dart';
import 'package:bastide/core/widgets/primary_button.dart';
import 'package:bastide/features/accounts/application/settlement_rule_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/settlement_rule.dart';
import 'package:bastide/features/accounts/presentation/settlement_rule_dialog.dart';
import 'package:bastide/features/rules/application/rule_preview_controller.dart';
import 'package:bastide/features/rules/domain/rule.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _card = Account(
  id: 'card',
  name: 'Carte ••4821',
  type: AccountType.deferredCard,
  institution: 'Crédit Agricole',
  currency: 'EUR',
  settlementAccountId: 'checking',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// Answers every preview with a fixed count, recording what was asked.
class _FakePreview extends RulePreviewController {
  final patterns = <String>[];
  final dates = <DateTime?>[];

  @override
  void request({
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
    DateTime? appliesFrom,
  }) {
    patterns.add(pattern);
    dates.add(appliesFrom);
    state = RulePreviewState(
      preview: RulePreview(
        matchCount: 9,
        samples: [
          RuleSample(
            id: 't1',
            descriptionClean: 'DEPENSES CARTE X4821 AU 29/09/26',
            bookedDate: DateTime(2026, 9, 30),
          ),
        ],
      ),
    );
  }
}

class _FakeSaver implements SettlementRuleController {
  _FakeSaver({this.fails = false});

  final bool fails;
  final saved = <(String, String, DateTime?)>[];

  @override
  Future<int> save(String cardId, String pattern, DateTime? appliesFrom) async {
    if (fails) throw Exception('boom');
    saved.add((cardId, pattern, appliesFrom));
    return 9;
  }
}

Widget _wrap({
  required SettlementRuleState state,
  required _FakePreview preview,
  required _FakeSaver saver,
  bool proposed = false,
  bool loadFails = false,
}) => ProviderScope(
  overrides: [
    settlementRuleProvider(
      'card',
    ).overrideWith((ref) async => loadFails ? throw Exception('boom') : state),
    rulePreviewControllerProvider.overrideWith(() => preview),
    settlementRuleControllerProvider.overrideWithValue(saver),
  ],
  child: MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showSettlementRuleDialog(context, _card, proposed: proposed),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

String _from(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('settlementRuleFromField')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets('proposes the suggested pattern and saves it', (tester) async {
    final preview = _FakePreview();
    final saver = _FakeSaver();
    await tester.pumpWidget(
      _wrap(
        state: SettlementRuleState(
          suggestedPattern: 'DEPENSES CARTE X4821',
          suggestedAppliesFrom: DateTime(2026, 1, 30),
        ),
        preview: preview,
        saver: saver,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('settlementRulePatternField')),
    );
    expect(field.controller!.text, 'DEPENSES CARTE X4821');
    expect(_from(tester), '30/01/2026');
    expect(preview.patterns, ['DEPENSES CARTE X4821']);
    // The preview counts what the rule will file: from its start date only.
    expect(preview.dates, [DateTime(2026, 1, 30)]);
    expect(find.byKey(const Key('rulePreviewBanner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settlementRuleSaveButton')));
    await tester.pumpAndSettle();

    expect(saver.saved, [
      ('card', 'DEPENSES CARTE X4821', DateTime(2026, 1, 30)),
    ]);
    expect(
      find.text('Règle enregistrée : 9 prélèvements classés en virement.'),
      findsOneWidget,
    );
  });

  testWidgets('an existing rule is shown rather than the proposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: SettlementRuleState(
          ruleId: 'r1',
          pattern: 'CARTE X4821',
          suggestedPattern: 'DEPENSES CARTE X4821',
          suggestedAppliesFrom: DateTime(2026, 1, 30),
        ),
        preview: _FakePreview(),
        saver: _FakeSaver(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('settlementRulePatternField')),
    );
    expect(field.controller!.text, 'CARTE X4821');
    // The saved rule has no start date, and keeps none: the user chose it.
    expect(_from(tester), '');
  });

  testWidgets('an unreadable start date is refused, not sent as none', (
    tester,
  ) async {
    final saver = _FakeSaver();
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(suggestedPattern: 'X4821'),
        preview: _FakePreview(),
        saver: saver,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('settlementRuleFromField')),
        matching: find.byType(TextField),
      ),
      '31/02/2026',
    );
    await tester.tap(find.byKey(const Key('settlementRuleSaveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Date invalide.'), findsOneWidget);
    expect(saver.saved, isEmpty);
  });

  testWidgets('an empty pattern is refused, and later saves nothing', (
    tester,
  ) async {
    final saver = _FakeSaver();
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(),
        preview: _FakePreview(),
        saver: saver,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settlementRuleSaveButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Indiquez le texte qui désigne le prélèvement.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settlementRuleSecondaryButton')));
    await tester.pumpAndSettle();
    expect(saver.saved, isEmpty);
    expect(find.byType(SettlementRuleDialog), findsNothing);
  });

  testWidgets('the v6 layout: lead in the header, mono pattern, two fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(suggestedPattern: 'PRLV CARTE X4821'),
        preview: _FakePreview(),
        saver: _FakeSaver(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final modal = tester.widget<AppModal>(find.byType(AppModal));
    expect(modal.width, AppModalSizes.w480);
    expect(modal.title, 'Règle de prélèvement de la carte');
    expect(
      (modal.subtitle! as Text).data,
      startsWith('Chaque mois, la banque prélève le total de Carte ••4821'),
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('settlementRulePatternField')),
    );
    expect(field.style!.fontFamily, contains('Mono'));
    expect(find.text('Le libellé du prélèvement contient'), findsOneWidget);
    expect(find.text('S’applique à partir du'), findsOneWidget);
    expect(find.text('Enregistrer la règle'), findsOneWidget);
  });

  testWidgets('the secondary reads « Annuler » when the user asked for it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(),
        preview: _FakePreview(),
        saver: _FakeSaver(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Plus tard'), findsNothing);
  });

  testWidgets('the secondary reads « Plus tard » when Bastide proposed it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(),
        preview: _FakePreview(),
        saver: _FakeSaver(),
        proposed: true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('a failed save stays open with the error, input kept', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(suggestedPattern: 'PRLV CARTE X4821'),
        preview: _FakePreview(),
        saver: _FakeSaver(fails: true),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settlementRuleSaveButton')));
    await tester.pumpAndSettle();

    expect(find.byType(SettlementRuleDialog), findsOneWidget);
    expect(find.byKey(const Key('appModalSaveError')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('settlementRulePatternField')),
          )
          .controller!
          .text,
      'PRLV CARTE X4821',
    );
  });

  testWidgets('a failed load offers a retry, and saving waits for it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(),
        preview: _FakePreview(),
        saver: _FakeSaver(),
        loadFails: true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modalLoadError')), findsOneWidget);
    expect(find.byKey(const Key('modalLoadErrorRetry')), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const Key('settlementRuleSaveButton')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('typed input asks before it is dropped', (tester) async {
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(suggestedPattern: 'X4821'),
        preview: _FakePreview(),
        saver: _FakeSaver(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settlementRulePatternField')),
      'PRLV CARTE X4821',
    );
    // The frame learns the form is dirty on the next frame.
    await tester.pump();
    await tester.tap(find.byKey(const Key('settlementRuleSecondaryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appModalDiscard')), findsOneWidget);
  });
}
