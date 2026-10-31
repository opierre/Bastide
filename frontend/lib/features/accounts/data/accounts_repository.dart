import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../domain/account.dart';
import '../domain/account_overview.dart';
import '../domain/card_settlement_status.dart';
import '../domain/settlement_rule.dart';

/// Calls the `/accounts` endpoints and maps the wire JSON to domain models.
/// The only place in the accounts feature that knows the response shape —
/// see the flutter-frontend skill's data-layer rule. `ApiClient` already
/// maps the `{error:{code,message}}` envelope to [ApiFailure], so failures
/// simply propagate.
class AccountsRepository {
  AccountsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Account>> list() async {
    final json = await _apiClient.get('/accounts') as List<dynamic>;
    return json
        .map((entry) => parseAccount(entry as Map<String, dynamic>))
        .toList();
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
    String? ofxAccountId,
    String? currency,
    String? settlementAccountId,
  }) async {
    final json = await _apiClient.post(
      '/accounts',
      body: {
        'name': name,
        'type': type.wireValue,
        'institution': institution,
        'opening_balance_minor': openingBalanceMinor,
        // Omitted rather than sent as null: the field is optional, and a blank
        // one would claim nothing anyway.
        'ofx_account_id': ?ofxAccountId,
        // Likewise: sent only when a source declared it (an OFX `CURDEF`), so
        // omitting it leaves the backend on its default — the user's currency.
        'currency': ?currency,
        'settlement_account_id': ?settlementAccountId,
      },
    );
    return parseAccount(json as Map<String, dynamic>);
  }

  Future<Account> update(
    String id, {
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
    String? settlementAccountId,
  }) async {
    final json = await _apiClient.patch(
      '/accounts/$id',
      body: {
        'name': name,
        'type': type.wireValue,
        'institution': institution,
        // A manual correction: the backend shifts the cache and every existing
        // snapshot by the delta rather than treating this as an independent
        // figure — see `shift_opening_balance`.
        'opening_balance_minor': openingBalanceMinor,
        // Always sent: a card's form always states it, and for any other
        // account it is null, which is what the backend keeps there anyway.
        'settlement_account_id': settlementAccountId,
      },
    );
    return parseAccount(json as Map<String, dynamic>);
  }

  /// Everything the account detail panel shows, in one read.
  Future<AccountOverview> overview(String id) async {
    final json =
        await _apiClient.get('/accounts/$id/overview') as Map<String, dynamic>;
    return parseOverview(json);
  }

  /// Maps the `AccountOverview` wire shape. Public so the mapping is tested
  /// against fixed JSON without a client.
  static AccountOverview parseOverview(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    final settlement = json['card_settlement'] as Map<String, dynamic>?;
    return AccountOverview(
      account: parseAccount(json['account'] as Map<String, dynamic>),
      firstTransactionDate: _date(json['first_transaction_date']),
      lastImportAt: switch (json['last_import_at']) {
        final String at => DateTime.parse(at),
        _ => null,
      },
      balanceHistory: [
        for (final point
            in (json['balance_history'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          BalancePoint(
            monthEnd: DateTime.parse(point['as_of'] as String),
            balanceMinor: point['balance_minor'] as int,
          ),
      ],
      period: PeriodStats(
        since: _date(period['since']),
        changeMinor: period['change_minor'] as int,
        inflowMinor: period['inflow_minor'] as int,
        outflowMinor: period['outflow_minor'] as int,
        consecutiveRisingMonths: period['consecutive_rising_months'] as int,
      ),
      linkedCards: [
        for (final card
            in (json['linked_cards'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          LinkedCard(
            accountId: card['id'] as String,
            name: card['name'] as String,
            institution: card['institution'] as String,
            cardLastDigits: card['card_last_digits'] as String?,
            cycleMinor: card['cycle_amount_minor'] as int,
            nextDebitDate: _date(card['next_debit_date']),
            // The card is linked here, so it has its settlement account: only
            // a missing rule is left to report as "no rule".
            hasRule: card['issue'] != 'no_rule',
          ),
      ],
      settlement: settlement == null
          ? null
          : _parseSettlement(settlement, json['card_last_digits'] as String?),
    );
  }

  static CardSettlement _parseSettlement(
    Map<String, dynamic> json,
    String? cardLastDigits,
  ) {
    final rule = json['rule'] as Map<String, dynamic>?;
    final cycles = [
      for (final cycle
          in (json['cycles'] as List<dynamic>).cast<Map<String, dynamic>>())
        SettlementCycle(
          settledOn: _date(cycle['settled_on']),
          amountMinor: cycle['amount_minor'] as int,
          // The open cycle is the one not settled yet.
          inProgress: cycle['settled_on'] == null,
        ),
    ];
    return CardSettlement(
      payingAccountId: json['settlement_account_id'] as String?,
      cardLastDigits: cardLastDigits,
      rule: rule == null
          ? null
          : SettlementRuleSummary(
              pattern: rule['pattern'] as String,
              enabled: rule['enabled'] as bool,
              appliesFrom: _date(rule['applies_from']),
            ),
      cycles: cycles,
      // The backend always ends the list with the open cycle.
      currentCycleMinor: cycles.isEmpty ? 0 : cycles.last.amountMinor,
      nextDebitDate: _date(json['next_debit_date']),
    );
  }

  Future<SettlementRuleState> settlementRule(String cardId) async {
    final json =
        await _apiClient.get('/accounts/$cardId/settlement-rule')
            as Map<String, dynamic>;
    final rule = json['rule'] as Map<String, dynamic>?;
    return SettlementRuleState(
      ruleId: rule?['id'] as String?,
      pattern: rule?['pattern'] as String?,
      appliesFrom: _date(rule?['applies_from']),
      suggestedPattern: json['suggested_pattern'] as String?,
      suggestedAppliesFrom: _date(json['suggested_applies_from']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  /// Creates or replaces the card's rule; resolves to how many imported rows
  /// it filed as a settlement.
  Future<int> saveSettlementRule(
    String cardId,
    String pattern,
    DateTime? appliesFrom,
  ) async {
    final json =
        await _apiClient.put(
              '/accounts/$cardId/settlement-rule',
              body: {
                'match_type': 'contains',
                'pattern': pattern,
                'applies_from': appliesFrom == null
                    ? null
                    : DateFormat('yyyy-MM-dd').format(appliesFrom),
              },
            )
            as Map<String, dynamic>;
    return json['recategorized_count'] as int;
  }

  Future<List<CardSettlementIssue>> settlementStatus() async {
    final json =
        await _apiClient.get('/accounts/settlement-status')
            as Map<String, dynamic>;
    return [
      for (final entry
          in (json['cards'] as List<dynamic>).cast<Map<String, dynamic>>())
        CardSettlementIssue(
          accountId: entry['account_id'] as String,
          kind: CardSettlementIssueKind.fromWire(entry['issue'] as String),
          amountMinor: entry['amount_minor'] as int?,
          count: entry['count'] as int?,
          since: switch (entry['since']) {
            final String date => DateTime.parse(date),
            _ => null,
          },
        ),
    ];
  }

  Future<void> archive(String id) async {
    await _apiClient.delete('/accounts/$id');
  }

  static Account parseAccount(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.fromWire(json['type'] as String),
    institution: json['institution'] as String,
    currency: json['currency'] as String,
    ofxAccountId: json['ofx_account_id'] as String?,
    settlementAccountId: json['settlement_account_id'] as String?,
    openingBalanceMinor: json['opening_balance_minor'] as int,
    balanceMinor: json['balance_minor'] as int,
    lastTransactionDate: switch (json['last_transaction_date']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
    archived: json['archived'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(apiClientProvider));
});
