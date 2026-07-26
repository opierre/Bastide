import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
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
        .login(email: _emailController.text.trim(), password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isSubmitting = authState.isLoading;

    return AuthScaffold(
      title: l10n.authLoginTitle,
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.authEmailLabel,
              child: TextFormField(
                key: const Key('loginEmailField'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.authEmailRequired : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.authPasswordLabel,
              child: TextFormField(
                key: const Key('loginPasswordField'),
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
                onFieldSubmitted: (_) => isSubmitting ? null : _submit(),
                validator: (value) =>
                    (value == null || value.isEmpty) ? l10n.authPasswordRequired : null,
              ),
            ),
            if (authState.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              InlineBanner(
                key: const Key('loginErrorText'),
                message: localizeAuthError(l10n, authState.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AuthSubmitButton(
              key: const Key('loginSubmitButton'),
              label: l10n.authLoginSubmit,
              isSubmitting: isSubmitting,
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
