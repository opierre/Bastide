import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the accounts panel was last laid out: its grouping and the sections
/// the user closed (`docs/design/05-accounts.md` §Behaviour). Kept on this
/// device, per user, like the sidebar's state: it describes the window, not
/// the user's money. Abstracted so the controller can be tested without the
/// platform store.
abstract class AccountsLayoutStore {
  /// `null` when nothing was saved yet.
  Future<String?> readGrouping(String userId);

  Future<void> writeGrouping(String userId, String grouping);

  /// The ids of the closed sections; `null` when nothing was saved yet.
  Future<List<String>?> readCollapsed(String userId);

  Future<void> writeCollapsed(String userId, List<String> sectionIds);
}

class SharedPreferencesAccountsLayoutStore implements AccountsLayoutStore {
  SharedPreferencesAccountsLayoutStore({SharedPreferencesAsync? preferences})
    : _injected = preferences;

  final SharedPreferencesAsync? _injected;

  /// Opened on first use, so a host without the platform store (a widget
  /// test) fails inside the calls the controller guards, not while building
  /// the provider.
  late final SharedPreferencesAsync _preferences =
      _injected ?? SharedPreferencesAsync();

  static String _groupingKey(String userId) => 'accounts_grouping.$userId';
  static String _collapsedKey(String userId) => 'accounts_collapsed.$userId';

  @override
  Future<String?> readGrouping(String userId) =>
      _preferences.getString(_groupingKey(userId));

  @override
  Future<void> writeGrouping(String userId, String grouping) =>
      _preferences.setString(_groupingKey(userId), grouping);

  @override
  Future<List<String>?> readCollapsed(String userId) =>
      _preferences.getStringList(_collapsedKey(userId));

  @override
  Future<void> writeCollapsed(String userId, List<String> sectionIds) =>
      _preferences.setStringList(_collapsedKey(userId), sectionIds);
}

final accountsLayoutStoreProvider = Provider<AccountsLayoutStore>(
  (ref) => SharedPreferencesAccountsLayoutStore(),
);
