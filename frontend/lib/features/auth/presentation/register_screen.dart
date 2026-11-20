import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../domain/display_name.dart';
import '../domain/password_rule.dart';
import '../domain/supported_currencies.dart';
import 'auth_error_localizer.dart';
import 'auth_link.dart';
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

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

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

  bool get _isValid =>
      isValidDisplayName(_displayNameController.text) &&
      _isEmail(_emailController.text.trim()) &&
      isLongEnoughPassword(_passwordController.text);

  Future<void> _submit(String locale) async {
    if (!_isValid || ref.read(authControllerProvider).isLoading) return;
    await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          locale: locale,
          currency: _currency,
        );
  }

  /// A taken or malformed name is that field's helper.
  String? _displayNameError(AppLocalizations l10n, Object? error) {
    if (error case ApiFailure(code: 'DISPLAY_NAME_TAKEN')) {
      return l10n.authDisplayNameTaken;
    }
    final name = _displayNameController.text;
    if (name.isNotEmpty && !isValidDisplayName(name)) {
      return l10n.authDisplayNameInvalid;
    }
    return null;
  }

  /// A taken or malformed e-mail is that field's helper, never a banner.
  String? _emailError(AppLocalizations l10n, Object? error) {
    if (error case ApiFailure(code: 'EMAIL_TAKEN')) {
      return l10n.authEmailTaken;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !_isEmail(email)) {
      return l10n.authEmailInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isSubmitting = authState.isLoading;
    final error = authState.hasError ? authState.error : null;
    final displayNameError = _displayNameError(l10n, error);
    final emailError = _emailError(l10n, error);
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

    void refresh(String _) => setState(() {});

    return AuthScaffold(
      children: [
        LabeledField(
          label: l10n.authRegisterDisplayNameLabel,
          errorText: displayNameError,
          child: AuthTextField(
            fieldKey: const Key('registerDisplayNameField'),
            controller: _displayNameController,
            autofillHints: const [AutofillHints.newUsername],
            autocorrect: false,
            enabled: !isSubmitting,
            hasError: displayNameError != null,
            onChanged: refresh,
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
            onChanged: refresh,
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
                onChanged: refresh,
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
            AuthLink(
              key: const Key('goToLoginButton'),
              label: l10n.authGoToLoginLink,
              onPressed: () => context.go(LoginScreen.path),
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
