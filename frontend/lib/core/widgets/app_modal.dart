import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The shared modal shell: an overlay-surface panel of a fixed width with a
/// title, a scrollable body, and a right-aligned action footer.
///
/// Replaces [AlertDialog], whose padding, title style and action layout all
/// drift from the spec. Each panel spec names its own width (480 for the account
/// form, 520 for the rule editor, 780 for the CSV wizard), so that is the one
/// required dimension.
class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.title,
    required this.width,
    required this.child,
    required this.actions,
  });

  final String title;
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
          color: AppColors.surfaceOverlay,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.modal,
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
                AppSpacing.md,
              ),
              child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
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
                spacing: AppSpacing.sm + AppSpacing.xs,
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
