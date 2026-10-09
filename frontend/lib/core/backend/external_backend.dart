import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend_connection.dart';

/// The port `bastide-backend` (and `uv run python -m app`) listens on when
/// none is given.
const defaultDevBackendUrl = 'http://127.0.0.1:8765';

/// A backend started outside the app, typically by a developer with
/// `uv run python -m app`, so the frontend keeps hot reload while the backend
/// keeps its own.
@immutable
class ExternalBackend {
  const ExternalBackend({required this.baseUrl, this.sessionToken});

  /// The API root, e.g. `http://127.0.0.1:8765/api/v1`.
  final Uri baseUrl;
  final String? sessionToken;
}

/// Decides whether to skip the supervisor and use a backend already running.
///
/// - `--dart-define=BASTIDE_BACKEND_URL=<origin>` always does, with the
///   optional `BASTIDE_SESSION_TOKEN` the backend was started with.
/// - A debug build with no packaged backend falls back to [defaultDevBackendUrl],
///   so a plain `flutter run` keeps working against `uv run python -m app`.
/// - A release build never does: it starts the backend it ships with.
ExternalBackend? resolveExternalBackend({
  required String url,
  required String sessionToken,
  required bool debug,
  required bool packagedBackendFound,
}) {
  final origin = url.isNotEmpty
      ? url
      : (debug && !packagedBackendFound ? defaultDevBackendUrl : null);
  if (origin == null) return null;
  final parsed = Uri.parse(origin);
  final path = parsed.path.replaceAll(RegExp(r'/+$'), '');
  return ExternalBackend(
    baseUrl: parsed.replace(path: path.isEmpty ? '/api/v1' : path),
    sessionToken: sessionToken.isEmpty ? null : sessionToken,
  );
}

/// Checks that [backend] answers, and reads the version it reports on
/// `/health` — what a started backend prints in its `READY` line.
Future<BackendConnection> probeExternalBackend(
  ExternalBackend backend, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(
          backend.baseUrl.replace(path: '${backend.baseUrl.path}/health'),
          headers: {sessionTokenHeader: ?backend.sessionToken},
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw BackendFailure(
        BackendFailureKind.unreachable,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return BackendConnection(
      baseUrl: backend.baseUrl,
      version: body['version'] as String? ?? '',
      sessionToken: backend.sessionToken,
    );
  } on BackendFailure {
    rethrow;
  } on Object catch (error) {
    throw BackendFailure(BackendFailureKind.unreachable, detail: '$error');
  } finally {
    if (client == null) httpClient.close();
  }
}
