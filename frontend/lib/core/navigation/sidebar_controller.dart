import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/ui_preferences.dart';

/// Whether the sidebar is collapsed to its icon-only rail
/// (`docs/design/00-design-system.md` §5).
///
/// Chrome state rather than feature state, so it lives in `core/` beside the
/// shell that reads it. It is a preference (Paramètres → Préférences →
/// Barre latérale, or `Ctrl+B`) kept on this device: it describes the window,
/// not the user's data, so it does not follow a backup to another machine.
class SidebarCollapsed extends Notifier<bool> {
  /// Set once the user chose, so a slow read of the saved value cannot undo a
  /// choice made while it was in flight.
  bool _chosen = false;

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final saved = await ref
          .read(uiPreferencesStoreProvider)
          .readSidebarCollapsed();
      if (saved != null && !_chosen && ref.mounted) state = saved;
    } catch (_) {
      // An unreadable store leaves the default, expanded sidebar.
    }
  }

  void toggle() => set(!state);

  void set(bool collapsed) {
    _chosen = true;
    if (collapsed == state) return;
    state = collapsed;
    unawaited(_save(collapsed));
  }

  Future<void> _save(bool collapsed) async {
    try {
      await ref
          .read(uiPreferencesStoreProvider)
          .writeSidebarCollapsed(collapsed);
    } catch (_) {
      // The window already follows the choice; it is only forgotten at the
      // next launch, which is not worth interrupting the user for.
    }
  }
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool>(
  SidebarCollapsed.new,
);
