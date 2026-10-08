import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// A freshly issued recovery code on an inset plate, with a copy button.
///
/// Shared by the post-registration screen and the Settings regeneration modal
/// so the code reads the same wherever the user first meets it. Monospace and
/// tracked out: it is copied by hand, character by character, onto paper.
class RecoveryCodePlate extends StatefulWidget {
  const RecoveryCodePlate({super.key, required this.code});

  final String code;

  @override
  State<RecoveryCodePlate> createState() => _RecoveryCodePlateState();
}

class _RecoveryCodePlateState extends State<RecoveryCodePlate> {
  // Ephemeral feedback only; nothing outside this plate cares.
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.inset),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.code,
              key: const Key('recoveryCodeText'),
              style: AppTextStyles.mono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            key: const Key('recoveryCodeCopyButton'),
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
            ),
            label: Text(
              _copied ? l10n.authRecoveryCodeCopied : l10n.authRecoveryCodeCopy,
            ),
          ),
        ],
      ),
    );
  }
}
