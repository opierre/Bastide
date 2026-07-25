import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../domain/supported_currencies.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const path = '/register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  String _locale = 'fr';
  String _currency = supportedCurrencies.first;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          locale: _locale,
          currency: _currency,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isSubmitting = authState.isLoading;

    return AuthScaffold(
      title: l10n.authRegisterTitle,
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.authDisplayNameLabel,
              child: TextFormField(
                key: const Key('registerDisplayNameField'),
                controller: _displayNameController,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authDisplayNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.authEmailLabel,
              child: TextFormField(
                key: const Key('registerEmailField'),
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
                key: const Key('registerPasswordField'),
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? l10n.authPasswordRequired : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.authLocaleLabel,
              child: AppSegmented<String>(
                value: _locale,
                onChanged: (value) => setState(() => _locale = value),
                segments: [
                  AppSegment(
                    key: const Key('registerLocaleFrenchOption'),
                    value: 'fr',
                    label: l10n.authLocaleFrench,
                  ),
                  AppSegment(
                    key: const Key('registerLocaleEnglishOption'),
                    value: 'en',
                    label: l10n.authLocaleEnglish,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.authCurrencyLabel,
              child: DropdownButtonFormField<String>(
                key: const Key('registerCurrencyField'),
                initialValue: _currency,
                borderRadius: BorderRadius.circular(AppRadii.md),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                items: [
                  for (final code in supportedCurrencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _currency = value);
                },
              ),
            ),
            if (authState.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              InlineErrorBanner(
                key: const Key('registerErrorText'),
                message: localizeAuthError(l10n, authState.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AuthSubmitButton(
              key: const Key('registerSubmitButton'),
              label: l10n.authRegisterSubmit,
              isSubmitting: isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: TextButton(
        key: const Key('goToLoginButton'),
        onPressed: () => context.go(LoginScreen.path),
        child: Text(l10n.authGoToLogin),
      ),
    );
  }
}
