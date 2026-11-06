import 'package:flutter/foundation.dart';

/// The user's uploaded picture as last fetched, with the ETag that lets the
/// next fetch answer « not modified » instead of sending the bytes again.
@immutable
class AvatarPicture {
  const AvatarPicture({required this.bytes, required this.etag});

  final Uint8List bytes;
  final String? etag;
}
