import 'package:bastide/core/api/api_client.dart';
import 'package:bastide/core/api/api_client_provider.dart';
import 'package:bastide/core/theme/app_theme.dart';
import 'package:bastide/features/accounts/application/accounts_controller.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/categories/domain/category.dart';
import 'package:bastide/features/settings/presentation/ai_settings_card.dart';
import 'package:bastide/features/transactions/application/transactions_controller.dart';
import 'package:bastide/features/transactions/domain/transaction.dart';
import 'package:bastide/features/transactions/presentation/review_queue.dart';
import 'package:bastide/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_accounts_controller.dart';
import '../../support/fake_transactions_controller.dart';

class MockApiClient extends Mock implements ApiClient {}

final _account = Account(
  id: 'a1',
  name: 'Compte courant',
  type: AccountType.checking,
  institution: 'BNP Paribas',
  currency: 'EUR',
  openingBalanceMinor: 0,
  balanceMinor: 0,
  archived: false,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

const _catalog = [
  AppCategory(
    id: 'c-electronics',
    userId: null,
    parentId: null,
    name: 'category.shopping.electronics',
    kind: 'expense',
    icon: 'devices',
    color: '#64748B',
    isSystem: true,
  ),
];

const _electronics = TransactionCategory(
  id: 'c-electronics',
  name: 'category.shopping.electronics',
  kind: 'expense',
  icon: 'devices',
  color: '#64748B',
);

final _row = Transaction(
  id: 't-proposed',
  accountId: 'a1',
  bookedDate: DateTime(2026, 5, 12),
  valueDate: null,
  amountMinor: -4990,
  currency: 'EUR',
  descriptionRaw: 'CB NOVATECH SAS 12/05',
  descriptionClean: 'Novatech',
  memo: null,
  merchant: 'Novatech',
  category: _electronics,
  categorizationSource: CategorizationSource.model,
  categorizationConfidence: 0.71,
  needsReview: true,
  fitid: null,
  dedupHash: 'hash-proposed',
  createdAt: DateTime.utc(2026, 5, 12),
  updatedAt: DateTime.utc(2026, 5, 12),
);

Map<String, dynamic> _settingsJson({required bool aiEnabled}) => {
  'ai_enabled': aiEnabled,
  'inference_base_url': 'http://127.0.0.1:11434/v1',
  'model_tag': 'gemma3n:e4b',
  'confidence_threshold': 0.8,
};

/// Turning the toggle off has to return the `07` review
/// queue to its rules-only rendering with the calm invitation — not merely persist
/// a boolean. Both live in one tree here, sharing the real availability
/// provider, because that is the only way the wiring between them is actually
/// exercised.
void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets(
    'turning AI off returns the review queue to its rules-only rendering',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The sidecar's copy, so a later GET reports what the PATCH stored — which
      // is exactly what the availability lookup behind the queue re-reads.
      var aiEnabled = true;

      final apiClient = MockApiClient();
      when(
        () => apiClient.get('/settings'),
      ).thenAnswer((_) async => _settingsJson(aiEnabled: aiEnabled));
      when(() => apiClient.get('/settings/inference/health')).thenAnswer(
        (_) async => {
          'reachable': true,
          'models': ['gemma3n:e4b'],
          'detail': null,
        },
      );
      when(
        () => apiClient.patch('/settings', body: any(named: 'body')),
      ).thenAnswer((invocation) async {
        final body = invocation.namedArguments[#body] as Map<String, Object?>;
        aiEnabled = body['ai_enabled'] as bool? ?? aiEnabled;
        return _settingsJson(aiEnabled: aiEnabled);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            transactionsControllerProvider.overrideWith(
              () => FakeTransactionsController(
                initialPage: TransactionsPage(
                  items: [_row],
                  page: 1,
                  pageSize: 50,
                  total: 1,
                ),
              ),
            ),
            transactionCategoriesProvider.overrideWith((ref) async => _catalog),
            accountsControllerProvider.overrideWith(
              () => FakeAccountsController(initialAccounts: [_account]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            theme: appDarkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Column(
                children: [
                  SizedBox(width: 640, child: AiSettingsCard()),
                  Expanded(child: _Queue()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AI on and answering: the queue offers its stage-2 rendering, so there is
      // nothing to invite the user to.
      expect(find.byKey(const Key('reviewAiInvitation')), findsNothing);

      await tester.tap(find.byKey(const Key('settingsAiToggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reviewAiInvitation')), findsOneWidget);
      expect(find.byKey(const Key('reviewAiInvitationLink')), findsOneWidget);
    },
  );
}

/// The queue, built with the one proposed row above. A separate widget only so
/// the tree above can stay `const`.
class _Queue extends StatelessWidget {
  const _Queue();

  @override
  Widget build(BuildContext context) => ReviewQueue(items: [_row], total: 1);
}
