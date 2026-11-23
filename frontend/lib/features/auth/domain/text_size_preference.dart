/// The app's text size, chosen in Settings › Préférences and stored on the
/// user. Every size of the type scale grows together; normal is the type scale
/// of `docs/design/00-design-system.md` §3 as written, and the default.
enum TextSizePreference {
  normal,
  large,
  xlarge;

  /// Reads the backend's `text_size` field. Anything unknown falls back to
  /// normal.
  static TextSizePreference fromWire(String? value) => switch (value) {
    'large' => large,
    'xlarge' => xlarge,
    _ => normal,
  };

  String get wire => name;
}
