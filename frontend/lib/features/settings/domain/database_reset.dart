import 'package:flutter/foundation.dart';

/// What this profile holds, as the danger zone's confirmation lists it
/// (`docs/design/09-settings.md` §Zone de danger, state ⑩).
///
/// [categories] counts the user's own categories only: the system catalog
/// belongs to the install, and a reset restores it rather than removing it.
@immutable
class DatabaseCounts {
  const DatabaseCounts({
    required this.accounts,
    required this.transactions,
    required this.categories,
    required this.rules,
    required this.recurring,
    required this.goals,
  });

  factory DatabaseCounts.fromJson(Map<String, dynamic> json) => DatabaseCounts(
    accounts: json['accounts'] as int,
    transactions: json['transactions'] as int,
    categories: json['categories'] as int,
    rules: json['rules'] as int,
    recurring: json['recurring'] as int,
    goals: json['goals'] as int,
  );

  final int accounts;
  final int transactions;
  final int categories;
  final int rules;
  final int recurring;
  final int goals;
}

/// Why a reset could not be carried out — one per backend error code.
enum ResetFailure {
  runActive,
  unknown;

  static ResetFailure fromCode(String? code) =>
      code == 'RESET_RUN_ACTIVE' ? runActive : unknown;
}

class ResetException implements Exception {
  const ResetException(this.failure);

  final ResetFailure failure;

  @override
  String toString() => 'ResetException($failure)';
}
