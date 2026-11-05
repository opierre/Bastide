import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/avatar_picture_controllers.dart';
import '../application/profile_controllers.dart';
import '../domain/avatar_choice.dart';
import 'avatar_crop_modal.dart';
import 'avatar_upload_failure_text.dart';

const _optionSize = 40.0;
const _previewSize = 56.0;

/// The « Avatar » card in Settings › Profil: the current avatar, the monogram
/// and the preset plates to pick from, a picture of the user's own, and a way
/// back — to the monogram from a preset, to the previous default from a
/// picture.
class AvatarCard extends ConsumerWidget {
  const AvatarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final state = ref.watch(avatarChoiceControllerProvider);
    final controller = ref.read(avatarChoiceControllerProvider.notifier);
    final picture = ref.watch(profilePictureControllerProvider);
    final pictureBytes = ref.watch(avatarPictureProvider).value?.bytes;
    final saving = state.isLoading || picture.busy;
    final hasPicture = user.avatar is PictureChoice;

    Future<void> pickPicture() async {
      final image = await ref
          .read(profilePictureControllerProvider.notifier)
          .pick();
      if (image == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AvatarCropModal(image: image),
      );
    }

    void choose(AvatarChoice choice) {
      if (saving || choice == user.avatar) return;
      controller.choose(choice);
    }

    final options = <AvatarChoice>[
      const MonogramChoice(),
      for (final preset in AvatarPreset.values) PresetChoice(preset),
    ];

    return AppCard(
      key: const Key('settingsAvatarCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(
                key: const Key('settingsAvatarPreview'),
                name: user.displayName,
                avatar: user.avatar,
                image: pictureBytes,
                size: _previewSize,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAvatarTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settingsAvatarSubtitle,
                      style: AppTextStyles.helper.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: const Key('settingsAvatarChoosePicture'),
                    onPressed: saving ? null : pickPicture,
                    child: Text(l10n.settingsAvatarChoosePicture),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (hasPicture)
                    TextButton(
                      key: const Key('settingsAvatarRemovePicture'),
                      onPressed: saving
                          ? null
                          : ref
                                .read(profilePictureControllerProvider.notifier)
                                .remove,
                      child: Text(l10n.settingsAvatarRemovePicture),
                    )
                  else
                    TextButton(
                      key: const Key('settingsAvatarReset'),
                      onPressed: saving || user.avatar is MonogramChoice
                          ? null
                          : () => choose(const MonogramChoice()),
                      child: Text(l10n.settingsAvatarReset),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm + 2,
            runSpacing: AppSpacing.sm + 2,
            children: [
              for (final option in options)
                _AvatarOption(
                  key: Key('settingsAvatarOption-${option.wire}'),
                  name: user.displayName,
                  choice: option,
                  label: _label(l10n, option),
                  selected: option == user.avatar,
                  onTap: saving ? null : () => choose(option),
                ),
            ],
          ),
          if (state.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(message: l10n.settingsAvatarError),
          ],
          if (picture.failure case final failure?) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('settingsAvatarPictureFailure'),
              message: avatarUploadFailureText(l10n, failure),
            ),
          ],
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, AvatarChoice choice) => switch (choice) {
    PresetChoice(:final preset) => l10n.settingsAvatarPreset(preset.name),
    _ => l10n.settingsAvatarMonogram,
  };
}

/// One pickable avatar: the plate inside a ring that turns iris when it is
/// the current choice, so selection isn't carried by the plate's hue alone.
class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    super.key,
    required this.name,
    required this.choice,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final AvatarChoice choice;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.inset),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.inset),
              border: Border.all(
                color: selected ? AppColors.focusRing : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: UserAvatar(name: name, avatar: choice, size: _optionSize),
          ),
        ),
      ),
    );
  }
}
