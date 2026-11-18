/// The app's theme, chosen in Settings › Préférences and stored on the user:
/// follow the operating system, or force dark or light. Dark is the default
/// (`docs/design/00-design-system.md` §1).
enum ThemePreference {
  system,
  dark,
  light;

  /// Reads the backend's `theme` field. Anything unknown falls back to dark.
  static ThemePreference fromWire(String? value) => switch (value) {
    'system' => system,
    'light' => light,
    _ => dark,
  };

  String get wire => name;
}
