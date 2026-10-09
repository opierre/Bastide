import 'package:flutter/foundation.dart';

/// The header carrying the per-launch session token (`app/core/session.py`).
const sessionTokenHeader = 'X-Bastide-Session';

/// Where the running backend answers, and how to prove we are the app that
/// started it.
@immutable
class BackendConnection {
  const BackendConnection({
    required this.baseUrl,
    required this.version,
    this.sessionToken,
    this.mismatchedAppVersion,
  });

  /// The API root, e.g. `http://127.0.0.1:52144/api/v1`.
  final Uri baseUrl;

  /// The product version the backend reports, compared with the app's own.
  final String version;

  /// Sent as `X-Bastide-Session` on every request. `null` only for a dev
  /// backend started without one, which then answers any local caller.
  final String? sessionToken;

  /// The app's own version when it differs from [version]. Only a debug
  /// build carries on with such a backend (usually a stale dev one), and
  /// warns about it; a release build refuses it.
  final String? mismatchedAppVersion;

  BackendConnection withMismatchedAppVersion(String appVersion) =>
      BackendConnection(
        baseUrl: baseUrl,
        version: version,
        sessionToken: sessionToken,
        mismatchedAppVersion: appVersion,
      );
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

  /// A backend the app did not start (dev mode) did not answer.
  unreachable,

  /// The database was written by a newer version of the app (exit code 10).
  schemaTooNew,

  /// It answered with a different product version than the app's.
  versionMismatch,
}

class BackendFailure implements Exception {
  const BackendFailure(
    this.kind, {
    this.exitCode,
    this.detail,
    this.appVersion,
    this.backendVersion,
  });

  final BackendFailureKind kind;

  /// The process exit code, when it exited.
  final int? exitCode;

  /// Diagnostic text for logs (the bad line, the backend's version…), never
  /// shown to the user as is.
  final String? detail;

  /// For [BackendFailureKind.versionMismatch]: the two versions, shown to
  /// the user so a support request says which install is out of step.
  final String? appVersion;
  final String? backendVersion;

  @override
  String toString() =>
      'BackendFailure(${kind.name}'
      '${exitCode == null ? '' : ', exit $exitCode'}'
      '${detail == null ? '' : ': $detail'})';
}
