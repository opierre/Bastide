import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/frame_texture.dart';
import '../../../l10n/app_localizations.dart';

/// Shared chrome for the signed-out screens: an ink page lit by two soft iris
/// glows, with the form on a single raised card.
///
/// The card holds *only the task* — no heading. What the screen is for is said
/// once, above the card, by the lockup and the tagline; repeating it as a card
/// title would put two competing headings on a 416px column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.form,
    required this.footer,
    required this.lockup,
    this.cardWidth = 416,
    this.tagline,
  });

  /// Login's variant: the wider lockup and the tagline.
  const AuthScaffold.login({
    super.key,
    required this.form,
    required this.footer,
    required String this.tagline,
  }) : cardWidth = 416,
       lockup = const BrandLockup.login();

  /// Register's variant: a smaller lockup and a wider card, with no tagline —
  /// the form is long enough that the extra line pushes the fields down for no
  /// gain, and the user has already read it on the way here.
  const AuthScaffold.register({
    super.key,
    required this.form,
    required this.footer,
  }) : cardWidth = 470,
       tagline = null,
       lockup = const BrandLockup.register();

  final Widget form;

  /// The "switch to the other screen" link, kept outside the card so the card
  /// contains only the task at hand.
  final Widget footer;

  final Widget lockup;
  final double cardWidth;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfaceSunken,
      body: FrameTexture(
        child: Stack(
          children: [
            const Positioned(
              top: -180,
              left: -140,
              child: _Glow(color: AppColors.iris),
            ),
            const Positioned(
              bottom: -220,
              right: -160,
              child: _Glow(color: AppColors.irisDeep),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: lockup),
                      if (tagline != null) ...[
                        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                        Text(
                          tagline!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                      _PrivacyLine(text: l10n.authPrivacyLine),
                      const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(color: AppColors.borderCard),
                          boxShadow: AppShadows.modal,
                        ),
                        child: form,
                      ),
                      const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                      Center(child: footer),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lock glyph + the local-and-private promise. It sits above the card rather
/// than inside it because it is about the product, not about the form.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textDisabled),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            text,
            key: const Key('authPrivacyLine'),
            textAlign: TextAlign.center,
            style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
          ),
        ),
      ],
    );
  }
}

/// A large, very low-opacity radial wash. Gives the ink background depth
/// without becoming a decorative element competing with the form.
class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 520,
        height: 520,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.07), color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
