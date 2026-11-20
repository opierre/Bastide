import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/tomettes.dart';
import '../../../l10n/app_localizations.dart';

/// The signed-out column (`docs/design/02-login.md`, `03-register.md`):
/// tomettes over the full frame, faded to nothing behind the form
/// (`00` §12), and one 320 px column set directly on the ground. No card,
/// no border, no shadow.
///
/// Top to bottom, 14 px apart: the brand row (8 px more below it), the
/// screen's own [children], then a hairline 8 px further down and the privacy
/// note under it. The note is the auth screens' one statement of the privacy
/// promise (`00` §14, rule 5).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: Tomettes()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: SizedBox(
                width: AppSizes.authColumn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: BrandLockup.login(),
                      ),
                    ),
                    for (final child in children) ...[
                      const SizedBox(height: AppSpacing.fieldGap),
                      child,
                    ],
                    const SizedBox(height: AppSpacing.fieldGap + AppSpacing.sm),
                    const _Hairline(),
                    const SizedBox(height: AppSpacing.fieldGap),
                    NoteLine(
                      key: const Key('authPrivacyLine'),
                      icon: LucideIcons300.lock,
                      text: l10n.authPrivacyLine,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 1 px `line` rule between the form and the privacy note.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.colors.line, child: const SizedBox(height: 1));
}
