import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';

/// A freshly issued recovery code (`02-login.md`, Behaviour): the code in
/// Geist Mono 16 on a `field` well, and a « Copier » secondary button.
///
/// Shared by the signed-out recovery code screen and the Settings
/// regeneration modal, so the code reads the same wherever the user first
/// meets it.
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
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.formField),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: colors.lineStrong),
            ),
            child: SelectableText(
              widget.code,
              key: const Key('recoveryCodeText'),
              style: context.textStyles.mono.copyWith(
                fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize,
                fontWeight: FontWeight.w400,
                color: colors.text,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton(
          key: const Key('recoveryCodeCopyButton'),
          label: _copied
              ? l10n.authRecoveryCodeCopied
              : l10n.authRecoveryCodeCopy,
          icon: _copied ? LucideIcons300.check : LucideIcons300.copy,
          onPressed: _copy,
        ),
      ],
    );
  }
}
