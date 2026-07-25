import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../domain/supported_currencies.dart';
import 'auth_error_localizer.dart';
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

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.authRegisterTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const Key('registerEmailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.authEmailLabel),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? l10n.authEmailRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('registerPasswordField'),
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? l10n.authPasswordRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('registerDisplayNameField'),
                    controller: _displayNameController,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(labelText: l10n.authDisplayNameLabel),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.authDisplayNameRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.authLocaleLabel, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        key: const Key('registerLocaleFrenchOption'),
                        label: Text(l10n.authLocaleFrench),
                        selected: _locale == 'fr',
                        onSelected: (_) => setState(() => _locale = 'fr'),
                      ),
                      ChoiceChip(
                        key: const Key('registerLocaleEnglishOption'),
                        label: Text(l10n.authLocaleEnglish),
                        selected: _locale == 'en',
                        onSelected: (_) => setState(() => _locale = 'en'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: const Key('registerCurrencyField'),
                    initialValue: _currency,
                    decoration: InputDecoration(labelText: l10n.authCurrencyLabel),
                    items: [
                      for (final code in supportedCurrencies)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _currency = value);
                    },
                  ),
                  if (authState.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      localizeAuthError(l10n, authState.error),
                      key: const Key('registerErrorText'),
                      style: const TextStyle(color: AppColors.negative),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('registerSubmitButton'),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.authRegisterSubmit),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const Key('goToLoginButton'),
                    onPressed: () => context.go(LoginScreen.path),
                    child: Text(l10n.authGoToLogin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
