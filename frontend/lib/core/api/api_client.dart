import 'dart:convert';
import 'dart:typed_data';

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

/// A binary response body with its headers (lower-cased names).
class ApiBytesResponse {
  const ApiBytesResponse({required this.bytes, required this.headers});

  final Uint8List bytes;
  final Map<String, String> headers;
}

/// Single typed HTTP client for the local sidecar. Owns bearer-header
/// injection, JSON encode/decode, and error-envelope mapping so no other
/// layer talks HTTP directly.
class ApiClient {
  ApiClient({Uri? baseUrl, http.Client? httpClient, this.tokenProvider})
    : baseUrl = baseUrl ?? Uri.parse('http://127.0.0.1:8765/api/v1'),
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

  /// Uploads a file alongside flat form fields (`POST /imports`).
  ///
  /// Multipart rather than JSON because the backend takes the statement file as
  /// an `UploadFile` — see `PROJECT.md` §5. The `Content-Type` header is left to
  /// [http.MultipartRequest], which has to append the generated boundary to it.
  Future<dynamic> postMultipart(
    String path, {
    required String fileField,
    required String fileName,
    required List<int> fileBytes,
    Map<String, String> fields = const {},
  }) async {
    final uri = baseUrl.replace(path: '${baseUrl.path}$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(json: false))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName),
      );

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  /// POSTs with no body and returns the raw bytes and headers — for endpoints
  /// that answer with a file (`POST /backup/export`). A failure still arrives
  /// as the JSON error envelope and is thrown as [ApiFailure].
  Future<ApiBytesResponse> postForBytes(String path) async {
    final uri = baseUrl.replace(path: '${baseUrl.path}$path');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(json: false))
      ..headers['Accept'] = '*/*';

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) _decode(response);
    return ApiBytesResponse(
      bytes: response.bodyBytes,
      headers: response.headers,
    );
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

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
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
