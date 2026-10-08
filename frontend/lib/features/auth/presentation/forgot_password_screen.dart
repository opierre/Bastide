import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recovery_controllers.dart';
import '../domain/password_strength.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';
import 'password_field.dart';
import 'password_strength_meter.dart';

/// « Mot de passe oublié » — sets a new password with the recovery code.
///
/// Success signs the user in with the replacement code pending, so the router
/// moves straight on to [RecoveryCodeScreen]; this screen never navigates
/// forward itself.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const path = '/forgot-password';

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Mirrors the new password so the strength meter follows each keystroke.
  PasswordStrength _strength = PasswordStrength.empty;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(passwordResetControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          recoveryCode: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resetState = ref.watch(passwordResetControllerProvider);
    final isSubmitting = resetState.isLoading;
    // Like login's credential error: the email/code pair failed, not a field,
    // so the reason is stated once and both fields take the error border.
    final hasPairError = resetState.hasError;

    return AuthScaffold(
      lockup: const BrandLockup.login(),
      tagline: l10n.authForgotPasswordTagline,
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPairError) ...[
              InlineBanner(
                key: const Key('resetErrorText'),
                message: localizeAuthError(l10n, resetState.error),
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            ],
            LabeledField(
              label: l10n.authEmailLabel,
              child: TextFormField(
                key: const Key('resetEmailField'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: hasPairError ? errorFieldDecoration() : null,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authEmailRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            LabeledField(
              label: l10n.authRecoveryCodeLabel,
              child: TextFormField(
                key: const Key('resetCodeField'),
                controller: _codeController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.mono.copyWith(
                  fontSize: 14,
                  letterSpacing: 1,
                  color: AppColors.textPrimary,
                ),
                decoration: hasPairError ? errorFieldDecoration() : null,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authRecoveryCodeRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            LabeledField(
              label: l10n.authNewPasswordLabel,
              helper:
                  _strength == PasswordStrength.empty || _strength.isAcceptable
                  ? null
                  : l10n.authPasswordStrengthHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    fieldKey: const Key('resetPasswordField'),
                    controller: _passwordController,
                    autofillHint: AutofillHints.newPassword,
                    onChanged: (value) =>
                        setState(() => _strength = scorePassword(value)),
                    validator: (value) => (value == null || value.isEmpty)
                        ? l10n.authPasswordRequired
                        : null,
                  ),
                  PasswordStrengthMeter(strength: _strength),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton.submit(
              key: const Key('resetSubmitButton'),
              label: l10n.authResetSubmit,
              loadingLabel: l10n.authResetSubmitting,
              isLoading: isSubmitting,
              // Same bar as registration: a reset must not be the way to a
              // password the register form would have refused.
              onPressed: _strength.isAcceptable ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.authResetNote,
              key: const Key('resetNote'),
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
      footer: TextButton(
        key: const Key('resetBackToLoginButton'),
        onPressed: () => context.go(LoginScreen.path),
        child: Text(l10n.authBackToLogin),
      ),
    );
  }
}
