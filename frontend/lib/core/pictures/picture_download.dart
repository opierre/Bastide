import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'pictures.dart';

/// Downloading a picture from an address the user pasted, for the uploads
/// that take a picture file.
///
/// The app downloads it itself and hands the bytes to the same crop and
/// upload steps as a picked file: the backend never makes a network call.

/// How long a download may take, from the request to the last byte.
const pictureDownloadTimeout = Duration(seconds: 15);

/// Why a picture could not be downloaded.
enum PictureDownloadFailure {
  /// Not an `http://` or `https://` address.
  invalidAddress,

  /// The server could not be reached, answered with an error, or was too
  /// slow.
  unreachable,

  /// Over [maxPictureUploadBytes], the cap of an upload.
  tooLarge,

  /// The bytes are not a picture the engine can decode.
  notAPicture,
}

/// The client downloads go through. Behind a provider so tests answer
/// without a network.
final pictureHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The `http`/`https` address in [input], or `null` when it isn't one.
Uri? parsePictureAddress(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

/// Downloads the picture at [address] and decodes it for the crop step.
///
/// Throws the [PictureDownloadFailure] that refused it. The size is checked
/// while the body streams in, so an oversized file is dropped as soon as it
/// crosses the cap rather than read to the end.
Future<ui.Image> downloadPicture(Ref ref, String address) async {
  final uri = parsePictureAddress(address);
  if (uri == null) throw PictureDownloadFailure.invalidAddress;
  final client = ref.read(pictureHttpClientProvider);
  final Uint8List bytes;
  try {
    bytes = await _readCapped(client, uri).timeout(pictureDownloadTimeout);
  } on PictureDownloadFailure {
    rethrow;
  } catch (_) {
    // Socket, TLS, redirect loop or timeout: all read as "unreachable".
    throw PictureDownloadFailure.unreachable;
  }
  try {
    return await ref.read(pictureImagingProvider).decode(bytes);
  } catch (_) {
    throw PictureDownloadFailure.notAPicture;
  }
}

Future<Uint8List> _readCapped(http.Client client, Uri uri) async {
  final response = await client.send(http.Request('GET', uri));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    // Cancelling the unread body releases the connection.
    unawaited(response.stream.listen(null).cancel());
    throw PictureDownloadFailure.unreachable;
  }
  if ((response.contentLength ?? 0) > maxPictureUploadBytes) {
    unawaited(response.stream.listen(null).cancel());
    throw PictureDownloadFailure.tooLarge;
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.stream) {
    builder.add(chunk);
    // Leaving the loop cancels the stream: the rest is never downloaded.
    if (builder.length > maxPictureUploadBytes) {
      throw PictureDownloadFailure.tooLarge;
    }
  }
  return builder.takeBytes();
}
