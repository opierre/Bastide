import 'dart:async';

import 'package:bastide/core/storage/ui_preferences.dart';

/// An in-memory [UiPreferencesStore], so no test reaches the platform store.
class FakeUiPreferencesStore implements UiPreferencesStore {
  FakeUiPreferencesStore({this.sidebarCollapsed, this.readGate});

  bool? sidebarCollapsed;

  /// When set, reads wait for it: lets a test act before the saved value lands.
  final Completer<void>? readGate;

  final writes = <bool>[];

  @override
  Future<bool?> readSidebarCollapsed() async {
    await readGate?.future;
    return sidebarCollapsed;
  }

  @override
  Future<void> writeSidebarCollapsed(bool collapsed) async {
    writes.add(collapsed);
    sidebarCollapsed = collapsed;
  }
}

/// A store whose every call fails, as a broken preferences file would.
class FailingUiPreferencesStore implements UiPreferencesStore {
  @override
  Future<bool?> readSidebarCollapsed() =>
      Future.error(StateError('unreadable'));

  @override
  Future<void> writeSidebarCollapsed(bool collapsed) =>
      Future.error(StateError('unwritable'));
}
