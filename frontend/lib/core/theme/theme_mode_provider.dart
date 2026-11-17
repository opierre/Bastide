import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/theme_preference.dart';
import '../session/current_user_provider.dart';

/// The [ThemeMode] the app runs in: the signed-in user's preference, dark
/// before anyone signs in. `system` follows the OS, and Flutter re-renders
/// when the OS switches.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(
    currentUserProvider.select((user) => user?.theme),
  );
  return switch (preference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark || null => ThemeMode.dark,
  };
});
