import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'password_field.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const path = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isSubmitting = authState.isLoading;

    // A rejected credential pair is a failure of the pair, not of one field —
    // so both fields take the error border and the reason is stated once, in a
    // banner, rather than being duplicated under each input.
    final hasCredentialError = authState.hasError;

    return AuthScaffold.login(
      tagline: l10n.authTagline,
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasCredentialError) ...[
              InlineBanner(
                key: const Key('loginErrorText'),
                message: localizeAuthError(l10n, authState.error),
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            ],
            LabeledField(
              label: l10n.authEmailLabel,
              child: TextFormField(
                key: const Key('loginEmailField'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: hasCredentialError ? errorFieldDecoration() : null,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authEmailRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            LabeledField(
              label: l10n.authPasswordLabel,
              child: PasswordField(
                fieldKey: const Key('loginPasswordField'),
                controller: _passwordController,
                hasError: hasCredentialError,
                onSubmitted: (_) => isSubmitting ? null : _submit(),
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.authPasswordRequired
                    : null,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('goToForgotPasswordButton'),
                onPressed: () => context.go(ForgotPasswordScreen.path),
                child: Text(l10n.authForgotPasswordLink),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton.submit(
              key: const Key('loginSubmitButton'),
              label: l10n.authLoginSubmit,
              loadingLabel: l10n.authLoginSubmitting,
              isLoading: isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: TextButton(
        key: const Key('goToRegisterButton'),
        onPressed: () => context.go(RegisterScreen.path),
        child: Text(l10n.authGoToRegister),
      ),
    );
  }
}
