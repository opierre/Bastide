import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_form_controllers.dart';
import '../domain/availability.dart';
import '../domain/display_name.dart';
import '../domain/email_address.dart';
import '../domain/password_rule.dart';
import '../domain/supported_currencies.dart';
import 'auth_error_localizer.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';
import 'new_password_helper.dart';
import 'password_field.dart';

/// « Inscription » (`docs/design/03-register.md`).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const path = '/register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  String _currency = supportedCurrencies.first;

  /// Set once the user leaves the password field, so a short password turns
  /// into an error only after they have moved on, not while they type.
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
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Every field well formed, and neither the name nor the e-mail taken or
  /// still being checked: one submit is then enough.
  bool get _isValid =>
      isValidDisplayName(_displayNameController.text) &&
      isValidEmail(_emailController.text.trim()) &&
      isLongEnoughPassword(_passwordController.text) &&
      !ref.read(registerAvailabilityProvider).blocksSubmit;

  Future<void> _submit(String locale) async {
    if (!_isValid || ref.read(registerControllerProvider).isLoading) return;
    await ref
        .read(registerControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          locale: locale,
          currency: _currency,
        );
  }

  /// A taken or malformed name is that field's helper. Taken shows as soon
  /// as the check run while typing answers, not only after a submit.
  String? _displayNameError(
    AppLocalizations l10n,
    Object? error,
    Availability availability,
  ) {
    if (availability == Availability.taken ||
        error is ApiFailure && error.code == 'DISPLAY_NAME_TAKEN') {
      return l10n.authDisplayNameTaken;
    }
    final name = _displayNameController.text;
    if (name.isNotEmpty && !isValidDisplayName(name)) {
      return l10n.authDisplayNameInvalid;
    }
    return null;
  }

  /// A taken or malformed e-mail is that field's helper, never a banner.
  String? _emailError(
    AppLocalizations l10n,
    Object? error,
    Availability availability,
  ) {
    if (availability == Availability.taken ||
        error is ApiFailure && error.code == 'EMAIL_TAKEN') {
      return l10n.authEmailTaken;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !isValidEmail(email)) {
      return l10n.authEmailInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submission = ref.watch(registerControllerProvider);
    final isSubmitting = submission.isLoading;
    final error = submission.hasError ? submission.error : null;
    final availability = ref.watch(registerAvailabilityProvider);
    final displayNameError = _displayNameError(
      l10n,
      error,
      availability.displayName,
    );
    final emailError = _emailError(l10n, error, availability.email);
    final password = _passwordController.text;
    final passwordShort = NewPasswordHelper.isError(
      password,
      flagShort: _passwordLeft,
    );
    // The language chosen here is the app's: the screen switches at once.
    final locale = Localizations.localeOf(context).languageCode;

    // Any other failure (network, validation) has no field of its own, so it
    // sits under the button that triggered it.
    final otherError =
        error != null && displayNameError == null && emailError == null
        ? localizeAuthError(l10n, error)
        : null;

    // Editing a field clears the error it answers, then re-validates; the
    // name and the e-mail are also checked against existing accounts.
    ValueChanged<String> edited(RegisterField field) => (value) {
      ref.read(registerControllerProvider.notifier).fieldEdited(field);
      final checks = ref.read(registerAvailabilityProvider.notifier);
      switch (field) {
        case RegisterField.email:
          checks.emailChanged(value);
        case RegisterField.displayName:
          checks.displayNameChanged(value);
        case RegisterField.password:
          break;
      }
      setState(() {});
    };

    return AuthScaffold(
      children: [
        LabeledField(
          label: l10n.authDisplayNameLabel,
          errorText: displayNameError,
          child: AuthTextField(
            fieldKey: const Key('registerDisplayNameField'),
            controller: _displayNameController,
            autofillHints: const [AutofillHints.newUsername],
            autocorrect: false,
            enabled: !isSubmitting,
            hasError: displayNameError != null,
            onChanged: edited(RegisterField.displayName),
          ),
        ),
        LabeledField(
          label: l10n.authEmailLabel,
          errorText: emailError,
          child: AuthTextField(
            fieldKey: const Key('registerEmailField'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enabled: !isSubmitting,
            hasError: emailError != null,
            onChanged: edited(RegisterField.email),
          ),
        ),
        LabeledField(
          label: l10n.authPasswordLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                fieldKey: const Key('registerPasswordField'),
                controller: _passwordController,
                focusNode: _passwordFocus,
                autofillHint: AutofillHints.newPassword,
                enabled: !isSubmitting,
                hasError: passwordShort,
                onChanged: edited(RegisterField.password),
                onSubmitted: (_) => _submit(locale),
              ),
              NewPasswordHelper(password: password, flagShort: _passwordLeft),
            ],
          ),
        ),
        _PreferencesRow(
          locale: locale,
          currency: _currency,
          enabled: !isSubmitting,
          onLocaleChanged: (value) =>
              ref.read(localeProvider.notifier).setLocale(Locale(value)),
          onCurrencyChanged: (value) => setState(() => _currency = value),
        ),
        Text(
          l10n.authPreferencesNote,
          key: const Key('registerPreferencesNote'),
          style: context.textStyles.helper.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton.submit(
              key: const Key('registerSubmitButton'),
              label: l10n.authRegisterSubmit,
              loadingLabel: l10n.authRegisterSubmitting,
              isLoading: isSubmitting,
              onPressed: _isValid ? () => _submit(locale) : null,
            ),
            if (otherError != null)
              FieldHelper(
                key: const Key('registerErrorText'),
                text: otherError,
                isError: true,
              ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            Text(
              l10n.authGoToLogin,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            AppLink(
              key: const Key('goToLoginButton'),
              label: l10n.authGoToLoginLink,
              onTap: () => context.go(LoginScreen.path),
            ),
          ],
        ),
      ],
    );
  }
}

/// « Langue » and « Devise » side by side, 12 px apart (`03-register.md`):
/// a segmented control and a 28 px select. The note under the row carries
/// the currency's permanence, so neither control needs warning styling.
class _PreferencesRow extends StatelessWidget {
  const _PreferencesRow({
    required this.locale,
    required this.currency,
    required this.enabled,
    required this.onLocaleChanged,
    required this.onCurrencyChanged,
  });

  final String locale;
  final String currency;
  final bool enabled;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledField(
            label: l10n.authLocaleLabel,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppSegmented<String>(
                value: locale,
                onChanged: enabled ? onLocaleChanged : null,
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
          ),
        ),
        const SizedBox(width: AppSpacing.smPlus),
        Expanded(
          child: LabeledField(
            label: l10n.authCurrencyLabel,
            child: AppSelect<String>(
              key: const Key('registerCurrencyField'),
              height: AppSizes.toolbarSelect,
              value: currency,
              items: [
                for (final code in supportedCurrencies)
                  AppSelectItem(
                    value: code,
                    label: l10n.authCurrencyOption(
                      code,
                      l10n.authCurrencyName(code),
                    ),
                  ),
              ],
              onChanged: enabled ? onCurrencyChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
