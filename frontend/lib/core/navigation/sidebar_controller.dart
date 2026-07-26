import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the sidebar is collapsed to its icon-only rail.
///
/// Chrome state rather than feature state, so it lives in `core/` beside the
/// shell that reads it. It is deliberately not persisted: the spec treats the
/// collapse as a momentary "give me more room" gesture, not a preference.
class SidebarCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool>(
  SidebarCollapsed.new,
);
