import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/avatar_picture_controllers.dart';
import '../application/profile_controllers.dart';
import '../domain/avatar_choice.dart';
import 'avatar_crop_modal.dart';
import 'avatar_upload_failure_text.dart';

/// The current avatar (`09-settings.md` §Profil).
const _previewSize = 48.0;

/// One pickable option.
const _optionSize = 32.0;

/// The ring around the current avatar and the selected option.
const _ringWidth = 2.0;

/// The controls of the « Avatar » row in Settings › Profil: the current
/// avatar ringed in `accent`, the monogram and the preset plates to pick from,
/// then « Choisir une photo », and « Retirer la photo » once one is set.
class AvatarPicker extends ConsumerWidget {
  const AvatarPicker({super.key});

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
      await showAppModal<void>(
        context: context,
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

    return Column(
      key: const Key('settingsAvatarPicker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.smPlus,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Ringed(
              child: UserAvatar(
                key: const Key('settingsAvatarPreview'),
                name: user.displayName,
                avatar: user.avatar,
                image: pictureBytes,
                size: _previewSize,
              ),
            ),
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
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              key: const Key('settingsAvatarChoosePicture'),
              label: l10n.settingsAvatarChoosePicture,
              icon: LucideIcons300.image,
              onPressed: saving ? null : pickPicture,
            ),
            if (hasPicture)
              AppButton(
                key: const Key('settingsAvatarRemovePicture'),
                label: l10n.settingsAvatarRemovePicture,
                variant: AppButtonVariant.ghost,
                onPressed: saving
                    ? null
                    : ref
                          .read(profilePictureControllerProvider.notifier)
                          .remove,
              ),
          ],
        ),
        if (state.hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(message: l10n.settingsAvatarError),
        ],
        if (picture.failure case final failure?) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            key: const Key('settingsAvatarPictureFailure'),
            message: avatarUploadFailureText(l10n, failure),
          ),
        ],
      ],
    );
  }

  String _label(AppLocalizations l10n, AvatarChoice choice) => switch (choice) {
    PresetChoice(:final preset) => l10n.settingsAvatarPreset(preset.name),
    _ => l10n.settingsAvatarMonogram,
  };
}

/// A 2 px `accent` ring with a 2 px gap around [child].
class _Ringed extends StatelessWidget {
  const _Ringed({required this.child, this.visible = true});

  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: visible ? context.colors.accent : Colors.transparent,
          width: _ringWidth,
        ),
      ),
      child: child,
    );
  }
}

/// One pickable avatar. The current choice carries the same ring as the
/// preview, so selection is never carried by the plate's hue alone.
class _AvatarOption extends StatefulWidget {
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
  State<_AvatarOption> createState() => _AvatarOptionState();
}

class _AvatarOptionState extends State<_AvatarOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: FocusableActionDetector(
          enabled: onTap != null,
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: onTap,
            child: FocusRing(
              focused: _focused,
              radius: AppRadii.full,
              child: _Ringed(
                visible: widget.selected,
                child: UserAvatar(
                  name: widget.name,
                  avatar: widget.choice,
                  size: _optionSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
