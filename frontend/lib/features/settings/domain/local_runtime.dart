import 'package:flutter/foundation.dart';

/// Where the downloadable local engine stands on this machine.
enum LocalRuntimeState {
  /// No build is pinned for this OS and architecture: nothing to offer.
  unsupported,

  /// Not (fully) on disk. A previous download may have left bytes to resume.
  absent,
  downloading,
  installed,

  /// The last download stopped on an error; see [LocalRuntime.error].
  failed,
}

/// Why the last download stopped short, as the backend's stable codes.
enum LocalRuntimeError { network, hashMismatch, diskFull, extract }

/// What `GET /settings/inference/runtime` reports.
@immutable
class LocalRuntime {
  const LocalRuntime({
    required this.state,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.modelTag,
    this.running = false,
    this.error,
  });

  factory LocalRuntime.fromJson(Map<String, dynamic> json) => LocalRuntime(
    state: switch (json['state'] as String) {
      'absent' => LocalRuntimeState.absent,
      'downloading' => LocalRuntimeState.downloading,
      'installed' => LocalRuntimeState.installed,
      'failed' => LocalRuntimeState.failed,
      _ => LocalRuntimeState.unsupported,
    },
    downloadedBytes: json['downloaded_bytes'] as int,
    totalBytes: json['total_bytes'] as int,
    modelTag: json['model_tag'] as String,
    running: json['running'] as bool? ?? false,
    error: switch (json['error']) {
      'network' => LocalRuntimeError.network,
      'hash_mismatch' => LocalRuntimeError.hashMismatch,
      'disk_full' => LocalRuntimeError.diskFull,
      'extract' => LocalRuntimeError.extract,
      _ => null,
    },
  );

  final LocalRuntimeState state;

  /// Bytes of [totalBytes] already on disk, a resumable partial included.
  final int downloadedBytes;

  /// What is still missing — before a download, the size to announce.
  final int totalBytes;

  /// The tag the engine serves its model under, to store as the model.
  final String modelTag;

  /// The server is up. It starts on the first request that needs a model.
  final bool running;

  final LocalRuntimeError? error;

  /// Share of the download done, in `[0,1]`.
  double get fraction =>
      totalBytes == 0 ? 0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  /// A previous download left bytes that the next one picks up from.
  bool get canResume => downloadedBytes > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRuntime &&
          other.state == state &&
          other.downloadedBytes == downloadedBytes &&
          other.totalBytes == totalBytes &&
          other.modelTag == modelTag &&
          other.running == running &&
          other.error == error);

  @override
  int get hashCode =>
      Object.hash(state, downloadedBytes, totalBytes, modelTag, running, error);
}
