import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_repository.dart';
import '../domain/account.dart';

/// Accounts list state: `AsyncValue<List<Account>>` per the flutter-frontend
/// skill. Mutations (`create`/`update`/`archive`) only replace `state` on
/// success, so a failed edit or archive surfaces to the caller (the form or
/// screen) as a thrown [ApiFailure] without discarding the already-loaded
/// list — unlike `AuthController`, a single account action failing shouldn't
/// blank out the whole panel.
class AccountsController extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() => ref.read(accountsRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(accountsRepositoryProvider).list());
  }

  /// Creates an account and returns it, so a caller that needs the new id —
  /// the imports panel, staging a statement for an account it just created —
  /// doesn't have to search the refreshed list for it.
  Future<Account> create({
    required String name,
    required AccountType type,
    required String institution,
    required int openingBalanceMinor,
  }) async {
    final account = await ref
        .read(accountsRepositoryProvider)
        .create(name: name, type: type, institution: institution, openingBalanceMinor: openingBalanceMinor);
    state = AsyncValue.data([...?state.value, account]);
    return account;
  }

  Future<void> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String institution,
  }) async {
    final updated = await ref
        .read(accountsRepositoryProvider)
        .update(id, name: name, type: type, institution: institution);
    state = AsyncValue.data([
      for (final account in state.value ?? const <Account>[])
        if (account.id == id) updated else account,
    ]);
  }

  Future<void> archive(String id) async {
    await ref.read(accountsRepositoryProvider).archive(id);
    state = AsyncValue.data(
      (state.value ?? const <Account>[]).where((account) => account.id != id).toList(),
    );
  }
}

final accountsControllerProvider = AsyncNotifierProvider<AccountsController, List<Account>>(
  AccountsController.new,
);
