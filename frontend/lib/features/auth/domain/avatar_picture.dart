import 'package:flutter/foundation.dart';

/// The largest picture file the backend accepts (`MAX_UPLOAD_BYTES`). Checked
/// before the file is read, so an oversized one is refused at once.
const maxAvatarUploadBytes = 10 * 1024 * 1024;

/// The user's uploaded picture as last fetched, with the ETag that lets the
/// next fetch answer « not modified » instead of sending the bytes again.
@immutable
class AvatarPicture {
  const AvatarPicture({required this.bytes, required this.etag});

  final Uint8List bytes;
  final String? etag;
}

/// Why a picture could not become the avatar. The current avatar is left as
/// it was in every case.
enum AvatarUploadFailure { tooLarge, invalidType, generic }
