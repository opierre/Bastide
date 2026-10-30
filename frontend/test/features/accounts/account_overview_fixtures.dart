import 'package:bastide/features/accounts/data/accounts_repository.dart';
import 'package:bastide/features/accounts/domain/account.dart';
import 'package:bastide/features/accounts/domain/account_overview.dart';

// Invented figures only — see the root CLAUDE.md on real data.

Map<String, dynamic> accountJson({
  String id = 'acc-1',
  String name = 'Compte courant',
  String type = 'checking',
  String institution = 'BNP Paribas',
  int balanceMinor = 348612,
  String? settlementAccountId,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'institution': institution,
  'currency': 'EUR',
  'ofx_account_id': null,
  'settlement_account_id': settlementAccountId,
  'opening_balance_minor': 120000,
  'balance_minor': balanceMinor,
  'last_transaction_date': '2026-10-29',
  'archived': false,
  'created_at': '2025-01-01T00:00:00Z',
  'updated_at': '2026-10-30T00:00:00Z',
};

Map<String, dynamic> checkingOverviewJson() => {
  'account': accountJson(),
  'first_transaction_date': '2025-01-03',
  'last_import_at': '2026-10-28T09:30:00Z',
  'balance_history': [
    {'month_end': '2026-08-31', 'balance_minor': 289045},
    {'month_end': '2026-09-30', 'balance_minor': 307420},
    {'month_end': '2026-10-30', 'balance_minor': 348612},
  ],
  'period': {
    'since': '2025-10-31',
    'change_minor': 124050,
    'inflow_minor': 2841000,
    'outflow_minor': -2716950,
    'consecutive_rising_months': 4,
  },
  'linked_cards': [
    {
      'account_id': 'card-1',
      'name': 'Visa Premier',
      'institution': 'BNP Paribas',
      'card_last_digits': '4821',
      'cycle_minor': -61240,
      'next_debit_date': '2026-11-05',
      'has_rule': true,
    },
    {
      'account_id': 'card-2',
      'name': 'Carte Business',
      'institution': 'BNP Paribas',
      'card_last_digits': null,
      'cycle_minor': -18490,
      'next_debit_date': null,
      'has_rule': false,
    },
  ],
  'settlement': null,
};

Map<String, dynamic> cardOverviewJson() => {
  'account': accountJson(
    id: 'card-1',
    name: 'Visa Premier',
    type: 'deferred_card',
    balanceMinor: -61240,
    settlementAccountId: 'acc-1',
  ),
  'first_transaction_date': '2025-02-07',
  'last_import_at': '2026-10-28T09:30:00Z',
  'balance_history': [
    {'month_end': '2026-09-30', 'balance_minor': -80360},
    {'month_end': '2026-10-30', 'balance_minor': -61240},
  ],
  'period': {
    'since': '2025-10-31',
    'change_minor': 0,
    'inflow_minor': 0,
    'outflow_minor': 0,
    'consecutive_rising_months': 0,
  },
  'linked_cards': <dynamic>[],
  'settlement': {
    'paying_account_id': 'acc-1',
    'card_last_digits': '4821',
    'rule': {
      'id': 'rule-1',
      'match_type': 'contains',
      'pattern': 'CARTE X4821',
      'enabled': true,
      'applies_from': '2025-02-05',
    },
    'cycles': [
      {'settled_on': '2026-08-05', 'amount_minor': -93175, 'in_progress': false},
      {'settled_on': '2026-09-05', 'amount_minor': -88420, 'in_progress': false},
      {'settled_on': '2026-10-05', 'amount_minor': -80360, 'in_progress': false},
      {'settled_on': null, 'amount_minor': -61240, 'in_progress': true},
    ],
    'current_cycle_minor': -61240,
    'next_debit_date': '2026-11-05',
  },
};

Map<String, dynamic> freshOverviewJson() => {
  'account': accountJson(
    id: 'acc-new',
    name: 'Compte joint',
    institution: 'Caisse Locale',
    balanceMinor: 0,
  ),
  'first_transaction_date': null,
  'last_import_at': null,
  'balance_history': [
    {'month_end': '2026-10-30', 'balance_minor': 0},
  ],
  'period': {
    'since': null,
    'change_minor': 0,
    'inflow_minor': 0,
    'outflow_minor': 0,
    'consecutive_rising_months': 0,
  },
  'linked_cards': <dynamic>[],
  'settlement': null,
};

AccountOverview overviewFrom(Map<String, dynamic> json) =>
    AccountsRepository.parseOverview(json);

Account accountFrom(Map<String, dynamic> json) =>
    AccountsRepository.parseAccount(json);
