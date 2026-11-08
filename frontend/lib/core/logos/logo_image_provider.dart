import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client_provider.dart';
import 'logo_ref.dart';

/// The bytes of one version of a rule's logo (`GET /rules/{id}/logo`).
///
/// Keyed by the whole [LogoRef], version included: every row showing the same
/// logo shares one download, the bytes stay in memory once fetched, and a
/// replaced logo — a new `updatedAt` — is fetched at once instead
/// of being served from the old entry. A failure is not retried: the chip
/// shows its monogram, and the next version of the rows asks again.
final logoImageProvider = FutureProvider.autoDispose.family<Uint8List, LogoRef>(
  (ref, logo) async {
    final response = await ref
        .watch(apiClientProvider)
        .getBytes('/rules/${logo.ruleId}/logo');
    // Kept after the last row scrolls away: scrolling back shouldn't
    // download the same picture again.
    ref.keepAlive();
    return response.bytes;
  },
  retry: (_, _) => null,
);
