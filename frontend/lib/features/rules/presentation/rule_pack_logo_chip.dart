import 'package:flutter/material.dart';

import '../../../core/widgets/monogram_avatar.dart';
import '../domain/rule_pack.dart';

/// A pack rule's logo as the import sheet previews it: the embedded picture on
/// the monogram's plate, or the monogram itself.
///
/// A linked logo shows the monogram: previewing never downloads anything, so
/// there is no picture to show until the user opts in and imports. An embedded
/// logo that doesn't decode falls back to the monogram too — the slot is never
/// a broken image.
class RulePackLogoChip extends StatelessWidget {
  const RulePackLogoChip({
    super.key,
    required this.entry,
    this.size = defaultSize,
  });

  static const defaultSize = 28.0;

  final RulePackEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final monogram = MonogramAvatar(name: entry.pattern, size: size);
    final bytes = entry.logo?.embeddedBytes;
    if (bytes == null) return monogram;

    return ClipRRect(
      // The monogram's own radius, so a row with a logo and a row without
      // line up as the same chip.
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.memory(
        bytes,
        key: const Key('rulePackLogoImage'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => monogram,
      ),
    );
  }
}
