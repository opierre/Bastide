import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/avatar_picker.dart';
import '../../auth/domain/password_rule.dart';
import '../../auth/presentation/display_name_modal.dart';
import '../../auth/presentation/password_change_modal.dart';
import '../../auth/presentation/recovery_code_modal.dart';
import 'setting_row.dart';

/// Profil: the avatar, the username and the email, then the password and the
/// recovery code, then signing out.
///
/// Neither security row shows a date: nothing records when the password or
/// the code last changed (`09-settings.md`).
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final name = user?.displayName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(title: l10n.settingsSectionProfile, first: true),
        SettingRow(
          key: const Key('settingsAvatarRow'),
          name: l10n.settingsAvatarTitle,
          description: l10n.settingsAvatarSubtitle,
          children: const [AvatarPicker()],
        ),
        SettingRow(
          key: const Key('settingsDisplayNameRow'),
          name: l10n.settingsProfileNameTitle,
          description: l10n.settingsProfileNameNote,
          children: [
            Wrap(
              spacing: AppSpacing.smPlus,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  key: const Key('settingsDisplayName'),
                  style: textTheme.bodyMedium,
                ),
                AppButton(
                  key: const Key('settingsDisplayNameButton'),
                  label: l10n.settingsProfileNameButton,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DisplayNameModal(initialName: name),
                  ),
                ),
              ],
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsEmailRow'),
          name: l10n.settingsEmailTitle,
          description: l10n.settingsEmailNote,
          children: [
            Text(
              user?.email ?? '',
              key: const Key('settingsEmail'),
              style: textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        SettingsGroupTitle(title: l10n.settingsGroupSecurity),
        SettingRow(
          key: const Key('settingsPasswordRow'),
          name: l10n.settingsPasswordTitle,
          description: l10n.settingsPasswordSubtitle(minPasswordLength),
          children: [
            AppButton(
              key: const Key('settingsPasswordButton'),
              label: l10n.settingsPasswordButton,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const PasswordChangeModal(),
              ),
            ),
          ],
        ),
        SettingRow(
          key: const Key('settingsRecoveryRow'),
          name: l10n.settingsRecoveryTitle,
          description: l10n.settingsRecoverySubtitle,
          children: [
            AppButton(
              key: const Key('settingsRecoveryButton'),
              label: l10n.settingsRecoveryButton,
              onPressed: () => showDialog<void>(
                context: context,
                // The code is shown once; a stray click outside must not
                // close the modal before it has been noted.
                barrierDismissible: false,
                builder: (_) => const RegenerateRecoveryCodeModal(),
              ),
            ),
          ],
        ),
        SettingsGroupTitle(title: l10n.settingsGroupSession),
        SettingRow(
          key: const Key('settingsLogoutRow'),
          name: l10n.settingsLogoutTitle,
          description: l10n.settingsLogoutNote,
          children: [
            AppButton(
              key: const Key('settingsLogoutButton'),
              label: l10n.userMenuLogout,
              icon: LucideIcons300.logOut,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ],
    );
  }
}
