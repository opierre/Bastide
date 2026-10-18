import 'package:flutter/foundation.dart';

/// What `GET /settings/updates` reports: whether the opt-in check is on and,
/// if so, whether a newer release is published.
///
/// The backend asks GitHub at most once a day and only when [enabled]; an
/// unreachable GitHub comes back as `reachable: false` on a 200, never as a
/// failure.
@immutable
class UpdateStatus {
  const UpdateStatus({
    required this.enabled,
    required this.currentVersion,
    this.latestVersion,
    this.updateAvailable = false,
    this.releaseUrl,
    this.checkedAt,
    this.reachable = true,
  });

  factory UpdateStatus.fromJson(Map<String, dynamic> json) => UpdateStatus(
    enabled: json['enabled'] as bool,
    currentVersion: json['current_version'] as String,
    latestVersion: json['latest_version'] as String?,
    updateAvailable: json['update_available'] as bool? ?? false,
    releaseUrl: switch (json['release_url']) {
      final String value => Uri.parse(value),
      _ => null,
    },
    checkedAt: switch (json['checked_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
    reachable: json['reachable'] as bool? ?? true,
  );

  final bool enabled;

  /// The version of the backend that answered, which is the app's version.
  final String currentVersion;

  /// The newest published release the last successful check found.
  final String? latestVersion;

  final bool updateAvailable;

  /// The release page to download from; set only when [updateAvailable].
  final Uri? releaseUrl;

  /// When GitHub last answered; `null` before the first successful check.
  final DateTime? checkedAt;

  /// `false` when the check was due and GitHub could not be reached.
  final bool reachable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpdateStatus &&
          other.enabled == enabled &&
          other.currentVersion == currentVersion &&
          other.latestVersion == latestVersion &&
          other.updateAvailable == updateAvailable &&
          other.releaseUrl == releaseUrl &&
          other.checkedAt == checkedAt &&
          other.reachable == reachable);

  @override
  int get hashCode => Object.hash(
    enabled,
    currentVersion,
    latestVersion,
    updateAvailable,
    releaseUrl,
    checkedAt,
    reachable,
  );
}
