import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recovery_controllers.dart';
import 'password_field.dart';
import 'recovery_code_plate.dart';

/// « Nouveau code de récupération », opened from the recovery code row of
/// Settings › Profil. Two steps in one modal: confirm the password, then show
/// the new code, once.
class RegenerateRecoveryCodeModal extends ConsumerStatefulWidget {
  const RegenerateRecoveryCodeModal({super.key});

  @override
  ConsumerState<RegenerateRecoveryCodeModal> createState() =>
      _RegenerateRecoveryCodeModalState();
}

class _RegenerateRecoveryCodeModalState
    extends ConsumerState<RegenerateRecoveryCodeModal> {
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The generate button's enabled state follows the field.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _generate() => ref
      .read(recoveryCodeRegenerateControllerProvider.notifier)
      .regenerate(password: _passwordController.text);

  String _errorMessage(AppLocalizations l10n, Object? error) =>
      error is ApiFailure && error.code == 'INVALID_CREDENTIALS'
      ? l10n.settingsRecoveryWrongPassword
      : l10n.authErrorGeneric;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(recoveryCodeRegenerateControllerProvider);
    final code = state.value;
    final isGenerating = state.isLoading;

    return AppModal(
      title: l10n.settingsRecoveryModalTitle,
      width: 480,
      actions: code != null
          ? [
              PrimaryButton(
                key: const Key('recoveryModalDone'),
                label: l10n.settingsRecoveryModalDone,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]
          : [
              AppButton(
                label: l10n.settingsRecoveryModalCancel,
                onPressed: isGenerating
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              PrimaryButton(
                key: const Key('recoveryModalGenerate'),
                label: l10n.settingsRecoveryModalGenerate,
                isLoading: isGenerating,
                onPressed: _passwordController.text.isEmpty ? null : _generate,
              ),
            ],
      subtitle: Text(
        code != null
            ? l10n.settingsRecoveryModalGenerated
            : l10n.settingsRecoveryModalLead,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code != null)
            RecoveryCodePlate(code: code)
          else ...[
            if (state.hasError) ...[
              InlineBanner(
                key: const Key('recoveryModalError'),
                message: _errorMessage(l10n, state.error),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
            ],
            LabeledField(
              label: l10n.authPasswordLabel,
              child: PasswordField(
                fieldKey: const Key('recoveryModalPasswordField'),
                controller: _passwordController,
                hasError: state.hasError,
                onSubmitted: (_) =>
                    isGenerating || _passwordController.text.isEmpty
                    ? null
                    : _generate(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
