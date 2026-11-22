import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_form_controllers.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'password_field.dart';
import 'register_screen.dart';

/// « Connexion » (`docs/design/02-login.md`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const path = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Set by a submit with an empty field, so the required errors only show
  /// once the user has asked to sign in, not on an untouched form.
  bool _attempted = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _identifierEmpty => _identifierController.text.trim().isEmpty;
  bool get _passwordEmpty => _passwordController.text.isEmpty;

  Future<void> _submit() async {
    if (ref.read(loginControllerProvider).isLoading) return;
    if (_identifierEmpty || _passwordEmpty) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _attempted = false);
    await ref
        .read(loginControllerProvider.notifier)
        .submit(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submission = ref.watch(loginControllerProvider);
    final isSubmitting = submission.isLoading;

    // A rejected pair is a failure of the pair, not of one field: both fields
    // take the error border and the reason is said once, under the password.
    final error = submission.hasError ? submission.error : null;
    final credentialsRejected =
        error is ApiFailure && error.code == 'INVALID_CREDENTIALS';

    final identifierError = _attempted && _identifierEmpty
        ? l10n.authIdentifierRequired
        : null;
    final passwordError = _attempted && _passwordEmpty
        ? l10n.authPasswordRequired
        : error != null
        ? localizeAuthError(l10n, error)
        : null;

    void onFieldChanged(String _) {
      if (_attempted) setState(() {});
    }

    return AuthScaffold(
      children: [
        LabeledField(
          label: l10n.authIdentifierLabel,
          errorText: identifierError,
          child: AuthTextField(
            fieldKey: const Key('loginIdentifierField'),
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            autocorrect: false,
            enabled: !isSubmitting,
            hasError: identifierError != null || credentialsRejected,
            onChanged: onFieldChanged,
            onSubmitted: (_) => _submit(),
          ),
        ),
        LabeledField(
          label: l10n.authPasswordLabel,
          errorText: passwordError,
          child: PasswordField(
            fieldKey: const Key('loginPasswordField'),
            controller: _passwordController,
            enabled: !isSubmitting,
            hasError: (_attempted && _passwordEmpty) || credentialsRejected,
            onChanged: onFieldChanged,
            onSubmitted: (_) => _submit(),
          ),
        ),
        PrimaryButton.submit(
          key: const Key('loginSubmitButton'),
          label: l10n.authLoginSubmit,
          loadingLabel: l10n.authLoginSubmitting,
          isLoading: isSubmitting,
          onPressed: _submit,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: AppLink(
                key: const Key('goToRegisterButton'),
                label: l10n.authGoToRegister,
                onTap: () => context.go(RegisterScreen.path),
              ),
            ),
            Flexible(
              child: AppLink(
                key: const Key('goToForgotPasswordButton'),
                label: l10n.authForgotPasswordLink,
                onTap: () => context.go(ForgotPasswordScreen.path),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
