import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../domain/password_strength.dart';
import '../domain/supported_currencies.dart';
import 'currency_label.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';
import 'password_field.dart';
import 'password_strength_meter.dart';

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

  /// Mirrors of the controllers, so the submit button's enabled state and the
  /// strength meter update as the user types rather than only on submit.
  String _displayName = '';
  String _email = '';
  PasswordStrength _strength = PasswordStrength.empty;

  bool get _isValid =>
      _displayName.trim().isNotEmpty &&
      _isEmail(_email.trim()) &&
      _strength.isAcceptable;

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

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

  /// The taken-email failure belongs to the email field, so it renders as that
  /// field's helper rather than as a banner over the whole form.
  String? _emailHelperError(
    AppLocalizations l10n,
    AsyncValue<Object?> authState,
  ) {
    if (authState.error case ApiFailure(code: 'EMAIL_TAKEN')) {
      return l10n.authEmailTaken;
    }
    if (_email.isNotEmpty && !_isEmail(_email.trim())) {
      return l10n.authEmailInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isSubmitting = authState.isLoading;
    final emailError = _emailHelperError(l10n, authState);

    return AuthScaffold.register(
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
                onChanged: (value) => setState(() => _displayName = value),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authDisplayNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            LabeledField(
              label: l10n.authEmailLabel,
              errorText: emailError,
              child: TextFormField(
                key: const Key('registerEmailField'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: emailError != null ? errorFieldDecoration() : null,
                onChanged: (value) => setState(() => _email = value),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.authEmailRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            LabeledField(
              label: l10n.authPasswordLabel,
              // The hint only appears once there is something to fix — an
              // empty field is not yet a mistake.
              helper:
                  _strength == PasswordStrength.empty || _strength.isAcceptable
                  ? null
                  : l10n.authPasswordStrengthHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    fieldKey: const Key('registerPasswordField'),
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
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _PreferencesRow(
              locale: _locale,
              currency: _currency,
              onLocaleChanged: (value) => setState(() => _locale = value),
              onCurrencyChanged: (value) => setState(() => _currency = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton.submit(
              key: const Key('registerSubmitButton'),
              label: l10n.authRegisterSubmit,
              isLoading: isSubmitting,
              onPressed: _isValid ? _submit : null,
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

/// Language and currency, grouped on an inset plate.
///
/// They sit together because neither is a credential — the plate says "this is
/// configuration", which is what lets the currency read as a settled value
/// rather than as one more thing to fill in. The note beneath carries the
/// permanence, so the control itself needs no warning styling.
class _PreferencesRow extends StatelessWidget {
  const _PreferencesRow({
    required this.locale,
    required this.currency,
    required this.onLocaleChanged,
    required this.onCurrencyChanged,
  });

  final String locale;
  final String currency;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeLocale = Localizations.localeOf(context).toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.authLocaleLabel,
            child: AppSegmented<String>(
              value: locale,
              onChanged: onLocaleChanged,
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
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          LabeledField(
            label: l10n.authCurrencyLabel,
            child: AppSelect<String>(
              key: const Key('registerCurrencyField'),
              value: currency,
              items: [
                for (final code in supportedCurrencies)
                  AppSelectItem(
                    value: code,
                    label: currencyLabel(code, activeLocale),
                  ),
              ],
              onChanged: onCurrencyChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            l10n.authPreferencesNote,
            key: const Key('registerPreferencesNote'),
            style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
