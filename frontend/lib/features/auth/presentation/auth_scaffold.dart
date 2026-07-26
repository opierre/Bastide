import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/app_localizations.dart';

/// Shared chrome for the signed-out screens: an ink page lit by two soft brand
/// glows, with the form on a single raised card. Login and register use it so
/// the two screens are indistinguishable apart from their fields.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.form,
    required this.footer,
  });

  final String title;
  final Widget form;

  /// The "switch to the other screen" link, kept outside the card so the card
  /// contains only the task at hand.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfaceSunken,
      body: Stack(
        children: [
          const Positioned(top: -180, left: -140, child: _Glow(color: AppColors.iris)),
          const Positioned(bottom: -220, right: -160, child: _Glow(color: AppColors.irisDeep)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLockup(markSize: 44, wordmarkSize: 24)),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                    Text(
                      l10n.authTagline,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.modal,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: textTheme.headlineSmall),
                          const SizedBox(height: AppSpacing.lg),
                          form,
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(child: footer),
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
            colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

/// The submit button used on both auth screens: full width, with the spinner
/// swapped in place so the button doesn't resize mid-submit.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String label;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSubmitting ? null : onPressed,
      child: isSubmitting
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textDisabled,
              ),
            )
          : Text(label),
    );
  }
}
