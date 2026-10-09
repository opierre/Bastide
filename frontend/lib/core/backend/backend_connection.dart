import 'package:flutter/foundation.dart';

/// Where the running backend answers, and how to prove we are the app that
/// started it.
@immutable
class BackendConnection {
  const BackendConnection({
    required this.baseUrl,
    required this.version,
    this.sessionToken,
  });

  /// The API root, e.g. `http://127.0.0.1:52144/api/v1`.
  final Uri baseUrl;

  /// The product version the backend reports, compared with the app's own.
  final String version;

  /// Sent as `X-Bastide-Session` on every request. `null` only for a dev
  /// backend started without one, which then answers any local caller.
  final String? sessionToken;
}

/// Why the backend could not be reached. Each kind gets its own localized
/// message on the startup screen.
enum BackendFailureKind {
  /// No backend executable where the packaged app puts it.
  notFound,

  /// It started but never printed its `READY` line in time.
  timeout,

  /// It exited, before or after becoming ready.
  crashed,

  /// Its first line on stdout was not the expected handshake.
  badHandshake,

  /// The database was written by a newer version of the app (exit code 10).
  schemaTooNew,

  /// It answered with a different product version than the app's.
  versionMismatch,
}

class BackendFailure implements Exception {
  const BackendFailure(this.kind, {this.exitCode, this.detail});

  final BackendFailureKind kind;

  /// The process exit code, when it exited.
  final int? exitCode;

  /// Diagnostic text for logs (the bad line, the backend's version…), never
  /// shown to the user as is.
  final String? detail;

  @override
  String toString() =>
      'BackendFailure(${kind.name}'
      '${exitCode == null ? '' : ', exit $exitCode'}'
      '${detail == null ? '' : ': $detail'})';
}
