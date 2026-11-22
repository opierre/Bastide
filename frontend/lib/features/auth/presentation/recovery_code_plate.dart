import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';

/// A freshly issued recovery code (`02-login.md`, Behaviour): the code in
/// Geist Mono 16 on a `field` well, and a « Copier » secondary button.
///
/// The well takes the full column width and the button sits under it, as in
/// the Settings regeneration modal: beside a button, the 320 px auth column
/// leaves the code too little room and it wraps onto two lines. The code is
/// kept on one line so its groups never split.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('recoveryCodeWell'),
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
            maxLines: 1,
            style: context.textStyles.mono.copyWith(
              fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize,
              fontWeight: FontWeight.w400,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            key: const Key('recoveryCodeCopyButton'),
            label: _copied
                ? l10n.authRecoveryCodeCopied
                : l10n.authRecoveryCodeCopy,
            icon: _copied ? LucideIcons300.check : LucideIcons300.copy,
            onPressed: _copy,
          ),
        ),
      ],
    );
  }
}
