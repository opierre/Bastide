import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences about this window rather than about the user's money: they stay
/// on the device and never reach the backend. Abstracted so the controllers
/// that read them can be tested without the platform store.
abstract class UiPreferencesStore {
  /// `null` when nothing was saved yet.
  Future<bool?> readSidebarCollapsed();

  Future<void> writeSidebarCollapsed(bool collapsed);
}

/// The platform's key/value store (a JSON file in the app's support folder on
/// Windows and Linux, `NSUserDefaults` on macOS).
class SharedPreferencesUiStore implements UiPreferencesStore {
  SharedPreferencesUiStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _sidebarCollapsedKey = 'sidebar_collapsed';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool?> readSidebarCollapsed() =>
      _preferences.getBool(_sidebarCollapsedKey);

  @override
  Future<void> writeSidebarCollapsed(bool collapsed) =>
      _preferences.setBool(_sidebarCollapsedKey, collapsed);
}

final uiPreferencesStoreProvider = Provider<UiPreferencesStore>(
  (ref) => SharedPreferencesUiStore(),
);
