import 'package:flutter/foundation.dart';

/// The user's server-side settings (`PROJECT.md` §4b `user_settings`).
///
/// These live on the backend, not in the Flutter store, because the *backend*
/// is what talks to the inference runtime — the address and model it dials are
/// its own configuration, and this screen is only the editor for them.
@immutable
class UserSettings {
  const UserSettings({
    required this.aiEnabled,
    required this.inferenceBaseUrl,
    required this.modelTag,
    required this.confidenceThreshold,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    aiEnabled: json['ai_enabled'] as bool,
    inferenceBaseUrl: json['inference_base_url'] as String,
    modelTag: json['model_tag'] as String?,
    confidenceThreshold: (json['confidence_threshold'] as num).toDouble(),
  );

  /// The user opts in — an install that has never been to this screen runs on
  /// rules alone.
  final bool aiEnabled;

  /// OpenAI-compatible base, loopback only. A non-loopback value is refused by
  /// the backend with a 422 (see `SettingsController.baseUrlError`).
  final String inferenceBaseUrl;

  /// The runtime's own model identifier; `null` means "whatever it lists first".
  final String? modelTag;

  /// Confidence floor in `[0,1]`. Below it a transaction is proposed for review
  /// rather than assigned (`PROJECT.md` §7).
  final double confidenceThreshold;

  /// The same floor as the whole percent the card shows. The stored value is
  /// the `[0,1]` real the API defines; the percentage exists only for display,
  /// so — like money and dates — the conversion happens at this edge and never
  /// in the wire model.
  int get confidenceThresholdPercent => (confidenceThreshold * 100).round();

  /// Builds the `[0,1]` value for a percentage taken off the slider.
  static double thresholdFromPercent(int percent) => percent.clamp(0, 100) / 100;

  UserSettings copyWith({
    bool? aiEnabled,
    String? inferenceBaseUrl,
    String? modelTag,
    double? confidenceThreshold,
  }) => UserSettings(
    aiEnabled: aiEnabled ?? this.aiEnabled,
    inferenceBaseUrl: inferenceBaseUrl ?? this.inferenceBaseUrl,
    modelTag: modelTag ?? this.modelTag,
    confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettings &&
          other.aiEnabled == aiEnabled &&
          other.inferenceBaseUrl == inferenceBaseUrl &&
          other.modelTag == modelTag &&
          other.confidenceThreshold == confidenceThreshold);

  @override
  int get hashCode =>
      Object.hash(aiEnabled, inferenceBaseUrl, modelTag, confidenceThreshold);
}

/// What `GET /settings/inference/health` reports about the configured runtime.
///
/// `reachable: false` is a normal, reportable state carried on a 200 — the app
/// works with no runtime at all — so this is never modelled as a failure.
@immutable
class InferenceHealth {
  const InferenceHealth({
    required this.reachable,
    this.models = const [],
    this.detail,
  });

  factory InferenceHealth.fromJson(Map<String, dynamic> json) => InferenceHealth(
    reachable: json['reachable'] as bool,
    models: (json['models'] as List<dynamic>? ?? const [])
        .map((tag) => tag as String)
        .toList(growable: false),
    detail: json['detail'] as String?,
  );

  /// What a probe that could not even be sent resolves to.
  static const unreachable = InferenceHealth(reachable: false);

  final bool reachable;

  /// The tags the runtime offers, in the order it listed them.
  final List<String> models;

  /// The runtime's own reason for being unreachable. Diagnostic text from
  /// another process, so it is never rendered as UI copy.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InferenceHealth &&
          other.reachable == reachable &&
          listEquals(other.models, models) &&
          other.detail == detail);

  @override
  int get hashCode => Object.hash(reachable, Object.hashAll(models), detail);
}
