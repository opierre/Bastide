import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reset_controller.dart';
import 'reset_confirm_modal.dart';
import 'reset_format.dart';
import 'setting_row.dart';

/// « Réinitialisation » in Settings › Données, last: the way out (export)
/// is read before the way through.
///
/// The row carries the danger button only; the solid destructive fill
/// appears once, in the confirmation this row can only open.
class ResetGroup extends ConsumerWidget {
  const ResetGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final failure = ref.watch(resetControllerProvider).failure;

    return Column(
      key: const Key('settingsDangerZoneCard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(title: l10n.settingsResetTitle),
        SettingRow(
          key: const Key('settingsResetRow'),
          name: l10n.settingsResetRowTitle,
          description: l10n.settingsResetSubtitle,
          children: [
            AppButton(
              key: const Key('settingsResetButton'),
              label: l10n.settingsResetButton,
              icon: LucideIcons300.trash2,
              variant: AppButtonVariant.danger,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ResetConfirmModal(),
              ),
            ),
            // A refused reset is reported here, not in the modal: the modal
            // has closed, and nothing was deleted.
            if (failure != null)
              InlineBanner(
                key: const Key('settingsResetError'),
                message: l10n.settingsResetRefused(
                  resetFailureMessage(l10n, failure),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
