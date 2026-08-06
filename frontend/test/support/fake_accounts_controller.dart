import 'package:finstride/features/accounts/application/accounts_controller.dart';
import 'package:finstride/features/accounts/domain/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A no-network `AccountsController` double for widget tests that only need
/// a fixed list state and/or to record which methods were called — without
/// touching the real API client.
class FakeAccountsController extends AccountsController {
  FakeAccountsController({this.initialAccounts = const [], this.createdAccount});

  final List<Account> initialAccounts;

  /// What [create] resolves to. Tests that only assert the call was made can
  /// leave it null; those that follow what the caller does with the new
  /// account (the imports panel selecting it) supply one.
  final Account? createdAccount;

  final createCalls =
      <
        ({
          String name,
          AccountType type,
          String institution,
          int openingBalanceMinor,
          String? ofxAccountId,
        })
      >[];
  final updateCalls = <({String id, String name, AccountType type, String institution})>[];
  final archiveCalls = <String>[];

  Object? errorOnCreate;
  Object? errorOnUpdate;
  Object? errorOnArchive;

  @override
  Future<List<Account>> build() async => initialAccounts;

  @override
  Future<Account> create({
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
    String? ofxAccountId,
  }) async {
    createCalls.add((
      name: name,
      type: type,
      institution: institution,
      openingBalanceMinor: openingBalanceMinor,
      ofxAccountId: ofxAccountId,
    ));
    if (errorOnCreate != null) throw errorOnCreate!;
    final account =
        createdAccount ??
        Account(
          id: 'created-${createCalls.length}',
          name: name,
          type: type,
          institution: institution,
          currency: 'EUR',
          ofxAccountId: ofxAccountId,
          openingBalanceMinor: openingBalanceMinor,
          balanceMinor: openingBalanceMinor,
          archived: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
    state = AsyncValue.data([...?state.value, account]);
    return account;
  }

  @override
  Future<void> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String institution,
  }) async {
    updateCalls.add((id: id, name: name, type: type, institution: institution));
    if (errorOnUpdate != null) throw errorOnUpdate!;
  }

  @override
  Future<void> archive(String id) async {
    archiveCalls.add(id);
    if (errorOnArchive != null) throw errorOnArchive!;
    state = AsyncValue.data((state.value ?? const []).where((a) => a.id != id).toList());
  }
}
