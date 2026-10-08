import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which group of settings the right-hand column is showing.
enum SettingsSection { profile, preferences, data, about }

/// A one-shot request, from outside the settings screen, to open it on a given
/// section — the top-bar user menu's "Edit profile" entry.
///
/// The open section itself stays local to the screen (it resets to
/// Preferences on every visit); this only carries the request across the
/// navigation. The screen consumes it once applied, so a later visit from the
/// sidebar opens on the default again.
class SettingsSectionRequest extends Notifier<SettingsSection?> {
  @override
  SettingsSection? build() => null;

  void request(SettingsSection section) => state = section;

  void consume() => state = null;
}

final settingsSectionRequestProvider =
    NotifierProvider<SettingsSectionRequest, SettingsSection?>(
      SettingsSectionRequest.new,
    );
