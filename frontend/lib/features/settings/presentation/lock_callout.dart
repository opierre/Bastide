import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The iris-tinted lock plate the Données cards carry: the AI card's privacy
/// promise, the backup card's "not encrypted" notice.
///
/// Not an `InlineBanner`: the banner tones are semantic — this is neither a
/// warning nor a success, it is a standing statement about where data goes.
class LockCallout extends StatelessWidget {
  const LockCallout({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: context.colors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: context.colors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.textStyles.helper.copyWith(
                color: context.colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
