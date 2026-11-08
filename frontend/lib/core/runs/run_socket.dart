import 'dart:async';
import 'dart:io';

/// One open progress socket, reduced to what [RunProgressClient] needs, so
/// tests can hand in a fake instead of a real connection.
abstract interface class RunSocket {
  /// Incoming frames (text frames arrive as `String`). Completes when the
  /// connection closes, from either side.
  Stream<Object?> get messages;

  /// The close code the server sent, once [messages] is done; `null` when the
  /// connection dropped without one.
  int? get closeCode;

  Future<void> close();
}

/// Opens a [RunSocket] to [url] with [headers]; throws when the handshake
/// fails (refused, HTTP 403 for a missing session token, timeout…).
typedef RunSocketConnector =
    Future<RunSocket> Function(Uri url, Map<String, String> headers);

/// The real connector: `dart:io`'s WebSocket, which takes request headers —
/// the desktop app has no browser in the way, so auth goes in the same
/// headers as REST rather than in the URL.
Future<RunSocket> connectIoRunSocket(
  Uri url,
  Map<String, String> headers,
) async {
  final socket = await WebSocket.connect(url.toString(), headers: headers);
  return _IoRunSocket(socket);
}

class _IoRunSocket implements RunSocket {
  _IoRunSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<Object?> get messages => _socket;

  @override
  int? get closeCode => _socket.closeCode;

  @override
  Future<void> close() => _socket.close();
}
