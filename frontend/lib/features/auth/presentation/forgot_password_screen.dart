import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recovery_controllers.dart';
import '../domain/password_rule.dart';
import 'auth_error_localizer.dart';
import 'auth_link.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';
import 'new_password_helper.dart';
import 'password_field.dart';

/// « Mot de passe oublié »: sets a new password with the recovery code, in
/// the login column (`02-login.md`, Behaviour).
///
/// Success signs the user in with the replacement code pending, so the router
/// moves straight on to the recovery code screen; this screen never navigates
/// forward itself.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const path = '/forgot-password';

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Set once the user leaves the new password, as on registration.
  bool _passwordLeft = false;
  bool _passwordFocused = false;

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() {
      // The node also notifies before it is ever focused, so only a loss of
      // focus it actually had counts as leaving the field.
      if (_passwordFocus.hasFocus) {
        _passwordFocused = true;
      } else if (_passwordFocused && !_passwordLeft) {
        setState(() => _passwordLeft = true);
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _confirmMismatch =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text != _passwordController.text;

  bool get _isValid =>
      _identifierController.text.trim().isNotEmpty &&
      _codeController.text.trim().isNotEmpty &&
      isLongEnoughPassword(_passwordController.text) &&
      _confirmController.text == _passwordController.text;

  Future<void> _submit() async {
    if (!_isValid || ref.read(passwordResetControllerProvider).isLoading) {
      return;
    }
    await ref
        .read(passwordResetControllerProvider.notifier)
        .submit(
          identifier: _identifierController.text.trim(),
          recoveryCode: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resetState = ref.watch(passwordResetControllerProvider);
    final isSubmitting = resetState.isLoading;
    final error = resetState.hasError ? resetState.error : null;
    // Like login's credential error: the identifier/code pair failed, not a
    // field, so both take the error border and the reason is said once.
    final pairRejected =
        error is ApiFailure && error.code == 'INVALID_RECOVERY_CODE';
    final password = _passwordController.text;

    void refresh(String _) => setState(() {});

    return AuthScaffold(
      children: [
        LabeledField(
          label: l10n.authIdentifierLabel,
          child: AuthTextField(
            fieldKey: const Key('resetIdentifierField'),
            controller: _identifierController,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            autocorrect: false,
            enabled: !isSubmitting,
            hasError: pairRejected,
            onChanged: refresh,
          ),
        ),
        LabeledField(
          label: l10n.authRecoveryCodeLabel,
          helper: l10n.authResetNote,
          errorText: error != null ? localizeAuthError(l10n, error) : null,
          child: AuthTextField(
            fieldKey: const Key('resetCodeField'),
            controller: _codeController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            enabled: !isSubmitting,
            hasError: pairRejected,
            style: context.textStyles.mono.copyWith(
              fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
              color: context.colors.text,
            ),
            onChanged: refresh,
          ),
        ),
        LabeledField(
          label: l10n.authNewPasswordLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                fieldKey: const Key('resetPasswordField'),
                controller: _passwordController,
                focusNode: _passwordFocus,
                autofillHint: AutofillHints.newPassword,
                enabled: !isSubmitting,
                hasError: NewPasswordHelper.isError(
                  password,
                  flagShort: _passwordLeft,
                ),
                onChanged: refresh,
              ),
              NewPasswordHelper(password: password, flagShort: _passwordLeft),
            ],
          ),
        ),
        LabeledField(
          label: l10n.authConfirmPasswordLabel,
          errorText: _confirmMismatch ? l10n.authPasswordMismatch : null,
          child: PasswordField(
            fieldKey: const Key('resetConfirmField'),
            controller: _confirmController,
            autofillHint: AutofillHints.newPassword,
            enabled: !isSubmitting,
            hasError: _confirmMismatch,
            onChanged: refresh,
            onSubmitted: (_) => _submit(),
          ),
        ),
        PrimaryButton.submit(
          key: const Key('resetSubmitButton'),
          label: l10n.authResetSubmit,
          loadingLabel: l10n.authResetSubmitting,
          isLoading: isSubmitting,
          onPressed: _isValid ? _submit : null,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthLink(
            key: const Key('resetBackToLoginButton'),
            label: l10n.authBackToLogin,
            onPressed: () => context.go(LoginScreen.path),
          ),
        ),
      ],
    );
  }
}
