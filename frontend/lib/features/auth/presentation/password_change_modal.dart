import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/profile_controllers.dart';
import '../domain/password_rule.dart';
import 'auth_error_localizer.dart';
import 'new_password_helper.dart';
import 'password_field.dart';

/// « Changer le mot de passe », the 420 px modal opened from the password row
/// of Settings › Profil (`09-settings.md`, Password modal): the current
/// password, then the new one with its confirmation.
///
/// A wrong current password is refused under its field; any other failure
/// is the frame's save banner. Success closes the modal and toasts; this
/// session stays open.
class PasswordChangeModal extends ConsumerStatefulWidget {
  const PasswordChangeModal({super.key});

  @override
  ConsumerState<PasswordChangeModal> createState() =>
      _PasswordChangeModalState();
}

class _PasswordChangeModalState extends ConsumerState<PasswordChangeModal> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newFocus = FocusNode();

  /// Set once the user leaves the new password, as on registration.
  bool _newLeft = false;
  bool _newFocused = false;

  @override
  void initState() {
    super.initState();
    _newFocus.addListener(() {
      // The node also notifies before it is ever focused, so only a loss of
      // focus it actually had counts as leaving the field.
      if (_newFocus.hasFocus) {
        _newFocused = true;
      } else if (_newFocused && !_newLeft) {
        setState(() => _newLeft = true);
      }
    });
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _currentController.text.isNotEmpty ||
      _newController.text.isNotEmpty ||
      _confirmController.text.isNotEmpty;

  bool get _confirmMismatch =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text != _newController.text;

  bool get _isValid =>
      _currentController.text.isNotEmpty &&
      isLongEnoughPassword(_newController.text) &&
      _confirmController.text == _newController.text;

  Future<void> _submit() async {
    if (!_isValid || ref.read(passwordChangeControllerProvider).isLoading) {
      return;
    }
    // Looked up before the await: the modal is gone when the toast is due.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final l10n = AppLocalizations.of(context)!;
    await ref
        .read(passwordChangeControllerProvider.notifier)
        .change(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    if (!mounted || ref.read(passwordChangeControllerProvider).hasError) {
      return;
    }
    Navigator.of(context).pop();
    if (overlay != null && overlay.mounted) {
      showAppToastOn(overlay, title: l10n.settingsPasswordChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(passwordChangeControllerProvider);
    final isSaving = state.isLoading;
    final error = state.hasError ? state.error : null;
    final wrongCurrent =
        error is ApiFailure && error.code == 'INVALID_CREDENTIALS';
    final newPassword = _newController.text;

    void refresh(String _) => setState(() {});

    return AppModal(
      key: const Key('passwordChangeModal'),
      title: l10n.settingsPasswordModalTitle,
      subtitle: Text(l10n.settingsPasswordModalLead),
      width: AppModalSizes.w420,
      dirty: _dirty,
      busy: isSaving,
      saveError: error == null || wrongCurrent
          ? null
          : localizeAuthError(l10n, error),
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('passwordModalCancel')),
        PrimaryButton(
          key: const Key('passwordModalSave'),
          label: l10n.settingsPasswordModalSave,
          isLoading: isSaving,
          onPressed: _isValid ? _submit : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.settingsPasswordCurrentLabel,
            errorText: wrongCurrent ? l10n.settingsPasswordWrongPassword : null,
            child: PasswordField(
              fieldKey: const Key('passwordModalCurrentField'),
              controller: _currentController,
              hasError: wrongCurrent,
              onChanged: refresh,
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          LabeledField(
            label: l10n.authNewPasswordLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  fieldKey: const Key('passwordModalNewField'),
                  controller: _newController,
                  focusNode: _newFocus,
                  autofillHint: AutofillHints.newPassword,
                  hasError: NewPasswordHelper.isError(
                    newPassword,
                    flagShort: _newLeft,
                  ),
                  onChanged: refresh,
                ),
                NewPasswordHelper(password: newPassword, flagShort: _newLeft),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          LabeledField(
            label: l10n.authConfirmPasswordLabel,
            errorText: _confirmMismatch ? l10n.authPasswordMismatch : null,
            child: PasswordField(
              fieldKey: const Key('passwordModalConfirmField'),
              controller: _confirmController,
              autofillHint: AutofillHints.newPassword,
              hasError: _confirmMismatch,
              onChanged: refresh,
            ),
          ),
        ],
      ),
    );
  }
}
