import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logos/logo_image_provider.dart';
import '../logos/logo_ref.dart';
import 'monogram_avatar.dart';

/// Institution/merchant avatar: the [MonogramAvatar], or the logo the user
/// uploaded on a categorization rule that matches this row.
///
/// The app never ships or fetches third-party logos; a [logo] is always the
/// user's own upload, served by the local backend. The monogram stays the
/// fallback while the picture loads, when it can't be fetched and when it
/// doesn't decode, so the chip never renders broken or empty.
class InstitutionAvatar extends ConsumerWidget {
  const InstitutionAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.logo,
  });

  final String name;
  final double size;

  /// The rule logo this row shows; `null` for the monogram.
  final LogoRef? logo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monogram = MonogramAvatar(name: name, size: size);
    final logo = this.logo;
    if (logo == null) return monogram;
    final bytes = ref.watch(logoImageProvider(logo)).value;
    if (bytes == null) return monogram;
    return ClipRRect(
      key: const Key('institutionAvatarLogo'),
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => monogram,
      ),
    );
  }
}
