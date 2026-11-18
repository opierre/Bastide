import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The modal of `docs/design/00-design-system.md` §7: `surface`, radius 12,
/// `shadow`, on `scrim`; padding 24; title 16/600 with an optional lead
/// below it; a scrollable body; the footer right-aligned, secondary then
/// primary, 8 px apart. Only for a task that needs protected focus (a form,
/// a confirmation).
///
/// Replaces [AlertDialog], whose padding, title style and action layout all
/// drift from the spec. Each panel spec names its own width, so that is the
/// one required dimension.
/// Fields sit 14 px apart in a modal (`00` §7), and the body 14 px below the
/// title.
const _fieldGap = 14.0;

class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.title,
    required this.width,
    required this.child,
    required this.actions,
    this.subtitle,
    this.leading,
  });

  final String title;

  /// Optional glyph plate set before the title — the destructive confirmations
  /// draw one (`docs/design/09-settings.md` state ⑩) so the modal announces its
  /// weight before the copy is read.
  final Widget? leading;

  /// Optional lead under the title, 13 `textSecondary` when it is a [Text]
  /// without a colour of its own.
  final Widget? subtitle;
  final double width;
  final Widget child;

  /// Footer buttons, laid out right-aligned in order. Cancel first, confirm
  /// last — the confirm action sits nearest the natural reading exit.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.modal),
          boxShadow: context.colors.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                _fieldGap,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          DefaultTextStyle.merge(
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.colors.textSecondary),
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              // A [Wrap], not a [Row]: French button labels run 15–20 % past
              // their English counterparts, and a three-action footer in a
              // 480 px modal has no room to spare. Identical to a row while the
              // actions fit, and it drops to a second line instead of
              // overflowing when they don't.
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
