import 'package:flutter/foundation.dart';

/// The preset plates a user can pick in Settings › Profil. The names are the
/// wire keys (`preset:<name>`); the hue each one paints is `AvatarHues`'.
enum AvatarPreset { cyan, blue, teal, pink, amber, lime, green, iris }

/// What the user's avatar shows: their initials monogram, their initials on a
/// preset plate, or a picture they uploaded.
@immutable
sealed class AvatarChoice {
  const AvatarChoice();

  /// Reads the backend's `avatar` field. Anything unknown, such as a preset
  /// a newer backend added, falls back to the monogram, never an empty slot.
  factory AvatarChoice.fromWire(String? value) {
    if (value == PictureChoice.wireValue) return const PictureChoice();
    if (value != null && value.startsWith(PresetChoice.wirePrefix)) {
      final key = value.substring(PresetChoice.wirePrefix.length);
      for (final preset in AvatarPreset.values) {
        if (preset.name == key) return PresetChoice(preset);
      }
    }
    return const MonogramChoice();
  }

  String get wire;
}

final class MonogramChoice extends AvatarChoice {
  const MonogramChoice();

  @override
  String get wire => 'monogram';

  @override
  bool operator ==(Object other) => other is MonogramChoice;

  @override
  int get hashCode => (MonogramChoice).hashCode;
}

final class PresetChoice extends AvatarChoice {
  const PresetChoice(this.preset);

  static const wirePrefix = 'preset:';

  final AvatarPreset preset;

  @override
  String get wire => '$wirePrefix${preset.name}';

  @override
  bool operator ==(Object other) =>
      other is PresetChoice && other.preset == preset;

  @override
  int get hashCode => preset.hashCode;
}

/// An uploaded picture, fetched separately from `GET /auth/me/avatar`.
final class PictureChoice extends AvatarChoice {
  const PictureChoice();

  static const wireValue = 'image';

  @override
  String get wire => wireValue;

  @override
  bool operator ==(Object other) => other is PictureChoice;

  @override
  int get hashCode => (PictureChoice).hashCode;
}
