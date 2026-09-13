import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What a [StatusPill] is reporting. Hue and meaning travel together so the
/// pill never rests on color alone — the dot repeats the hue, and the label
/// always names the condition in words.
enum StatusPillTone {
  /// Something worth a look: a price rise, a charge that hasn't landed. Amber
  /// rather than red on purpose — the panel reports, it does not scold
  /// (`PROJECT.md` §9: never punitive).
  warning(AppColors.warning, null),

  /// A settled, no-longer-running state — a cancelled subscription. Opaque
  /// slate rather than a tint, so it reads as inert beside an amber signal.
  neutral(AppColors.textSecondary, AppColors.surfaceHover);

  const StatusPillTone(this.foreground, this.background);

  final Color foreground;

  /// `null` means "the foreground at 14 %", the spec's tinted variant.
  final Color? background;
}

/// The 22 px status pill of the subscriptions panel (`docs/design/00`
/// §Phase 2 additions): a 6 px dot in the pill's own hue and an 11 px/700
/// label.
///
/// There is deliberately no "healthy" tone. A subscription that is simply
/// working has an empty Statut cell: a green "OK" on every ordinary row would
/// spend the user's attention on the seven rows that need none and leave the
/// one that does looking like the rest.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  final String label;
  final StatusPillTone tone;

  @override
  Widget build(BuildContext context) {
    final background =
        tone.background ?? tone.foreground.withValues(alpha: 0.14);

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tone.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.geist,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tone.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
