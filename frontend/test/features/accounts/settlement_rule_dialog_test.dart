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

  @override
  void request({
    required RuleMatchField matchField,
    required RuleMatchType matchType,
    required String pattern,
  }) {
    patterns.add(pattern);
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
  final saved = <(String, String)>[];

  @override
  Future<int> save(String cardId, String pattern) async {
    saved.add((cardId, pattern));
    return 9;
  }
}

Widget _wrap({
  required SettlementRuleState state,
  required _FakePreview preview,
  required _FakeSaver saver,
}) => ProviderScope(
  overrides: [
    settlementRuleProvider('card').overrideWith((ref) async => state),
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
          onPressed: () => showSettlementRuleDialog(context, _card),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('proposes the suggested pattern and saves it', (tester) async {
    final preview = _FakePreview();
    final saver = _FakeSaver();
    await tester.pumpWidget(
      _wrap(
        state: const SettlementRuleState(
          suggestedPattern: 'DEPENSES CARTE X4821',
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
    expect(preview.patterns, ['DEPENSES CARTE X4821']);
    expect(find.byKey(const Key('rulePreviewBanner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settlementRuleSaveButton')));
    await tester.pumpAndSettle();

    expect(saver.saved, [('card', 'DEPENSES CARTE X4821')]);
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
        state: const SettlementRuleState(
          ruleId: 'r1',
          pattern: 'CARTE X4821',
          suggestedPattern: 'DEPENSES CARTE X4821',
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

    await tester.tap(find.byKey(const Key('settlementRuleLaterButton')));
    await tester.pumpAndSettle();
    expect(saver.saved, isEmpty);
    expect(find.byType(SettlementRuleDialog), findsNothing);
  });
}
