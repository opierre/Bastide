import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/profile_controllers.dart';
import '../domain/email_address.dart';
import 'auth_error_localizer.dart';
import 'password_field.dart';

/// « Changer d’adresse e-mail », the 420 px modal opened from the email row
/// of Settings › Profil (`09-settings.md`, Email modal). The email is also a
/// login identifier, so the current password is asked first, as for the
/// recovery code: an unattended open session can't move the login elsewhere.
///
/// A malformed or taken address is refused under its field, a wrong password
/// under the password; any other failure is the frame's save banner, the
/// input kept.
class EmailChangeModal extends ConsumerStatefulWidget {
  const EmailChangeModal({super.key, required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<EmailChangeModal> createState() => _EmailChangeModalState();
}

class _EmailChangeModalState extends ConsumerState<EmailChangeModal> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  bool get _dirty =>
      _emailController.text != widget.initialEmail ||
      _passwordController.text.isNotEmpty;

  bool get _canSave =>
      isValidEmail(_email) &&
      _email != widget.initialEmail &&
      _passwordController.text.isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || ref.read(emailChangeControllerProvider).isLoading) {
      return;
    }
    await ref
        .read(emailChangeControllerProvider.notifier)
        .save(email: _email, currentPassword: _passwordController.text);
    if (!mounted) return;
    if (!ref.read(emailChangeControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  static String? _codeOf(Object? error) =>
      error is ApiFailure ? error.code : null;

  String? _emailError(AppLocalizations l10n, String? code) {
    if (_email.isNotEmpty && !isValidEmail(_email)) {
      return l10n.authEmailInvalid;
    }
    return switch (code) {
      'EMAIL_TAKEN' => l10n.settingsEmailTaken,
      'EMAIL_INVALID' => l10n.authEmailInvalid,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(emailChangeControllerProvider);
    final isSaving = state.isLoading;
    final error = state.hasError ? state.error : null;
    final code = _codeOf(error);
    final emailError = _emailError(l10n, code);
    final wrongPassword = code == 'INVALID_CREDENTIALS';
    final fieldHandled =
        wrongPassword || code == 'EMAIL_TAKEN' || code == 'EMAIL_INVALID';

    void refresh(String _) => setState(() {});

    return AppModal(
      key: const Key('emailChangeModal'),
      title: l10n.settingsEmailModalTitle,
      subtitle: Text(l10n.settingsEmailModalLead),
      width: AppModalSizes.w420,
      dirty: _dirty,
      busy: isSaving,
      saveError: error == null || fieldHandled
          ? null
          : localizeAuthError(l10n, error),
      onSubmit: _save,
      actions: [
        const AppModalCancel(key: Key('emailModalCancel')),
        PrimaryButton(
          key: const Key('emailModalSave'),
          label: l10n.settingsEmailModalSave,
          isLoading: isSaving,
          onPressed: _canSave ? _save : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.settingsEmailNewLabel,
            errorText: emailError,
            child: AuthTextField(
              fieldKey: const Key('emailModalField'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              hasError: emailError != null,
              onChanged: refresh,
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          LabeledField(
            label: l10n.settingsPasswordCurrentLabel,
            errorText: wrongPassword
                ? l10n.settingsPasswordWrongPassword
                : null,
            child: PasswordField(
              fieldKey: const Key('emailModalPasswordField'),
              controller: _passwordController,
              hasError: wrongPassword,
              onChanged: refresh,
            ),
          ),
        ],
      ),
    );
  }
}
