import 'dart:convert';

import 'package:http/http.dart' as http;

/// Typed failure mapped from the backend's `{error:{code,message,details}}`
/// envelope (see `PROJECT.md` §5). `code` is a stable, translatable key the
/// frontend maps to a localized message.
class ApiFailure implements Exception {
  const ApiFailure({required this.code, required this.message, this.details});

  factory ApiFailure.unknown() =>
      const ApiFailure(code: 'UNKNOWN_ERROR', message: 'Unexpected error');

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ApiFailure($code: $message)';
}

/// Single typed HTTP client for the local sidecar. Owns bearer-header
/// injection, JSON encode/decode, and error-envelope mapping so no other
/// layer talks HTTP directly.
class ApiClient {
  ApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.tokenProvider,
  }) : baseUrl = baseUrl ?? Uri.parse('http://127.0.0.1:8000/api/v1'),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;

  /// Hook returning the current bearer token, injected by the auth feature.
  final String? Function()? tokenProvider;

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _send('POST', path, body: body);
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path) {
    return _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = baseUrl.replace(
      path: '${baseUrl.path}$path',
      queryParameters: query,
    );
    final request = http.Request(method, uri)..headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = tokenProvider?.call();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      if (error == null) throw ApiFailure.unknown();
      throw ApiFailure(
        code: error['code'] as String? ?? 'UNKNOWN_ERROR',
        message: error['message'] as String? ?? 'Unexpected error',
        details: error['details'] as Map<String, dynamic>?,
      );
    }

    return decoded;
  }
}
