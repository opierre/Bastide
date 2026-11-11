import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pictures/picture_download.dart';
import '../../../core/pictures/pictures.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picture_crop_modal.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_logo_controller.dart';
import '../application/rule_logo_url_controller.dart';
import '../application/rules_controller.dart';

const _previewSize = 40.0;

/// The rule editor's « Logo » field: the chip the matched rows will show, and
/// the buttons to give the rule a logo, replace it or remove it.
///
/// A logo hangs off a saved rule, so while a rule is being created the field
/// only says to save it first. Changes apply at once, outside the editor's
/// « Enregistrer »: the upload is its own write, like the avatar's.
class RuleLogoField extends ConsumerWidget {
  const RuleLogoField({super.key, required this.ruleId, required this.name});

  /// The saved rule, or `null` while creating one.
  final String? ruleId;

  /// What the monogram fallback is drawn from: the rule's pattern.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ruleId = this.ruleId;
    // Read from the list rather than the rule the editor opened with: an
    // upload changes it while the editor stays open.
    final logo = ruleId == null
        ? null
        : ref.watch(
            rulesControllerProvider.select(
              (rules) => rules.value
                  ?.where((rule) => rule.id == ruleId)
                  .firstOrNull
                  ?.logo,
            ),
          );
    final state = ref.watch(ruleLogoControllerProvider);
    final controller = ref.read(ruleLogoControllerProvider.notifier);

    Future<void> crop(ui.Image image) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RuleLogoCropModal(ruleId: ruleId!, image: image),
    );

    Future<void> pick() async {
      final image = await controller.pick();
      if (image == null || !context.mounted) return;
      await crop(image);
    }

    Future<void> fromUrl() async {
      final image = await showDialog<ui.Image>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _RuleLogoUrlModal(),
      );
      if (image == null || !context.mounted) return;
      await crop(image);
    }

    return LabeledField(
      label: l10n.ruleFormLogoLabel,
      helper: ruleId == null
          ? l10n.ruleFormLogoSaveFirst
          : l10n.ruleFormLogoHelper,
      errorText: switch (state.failure) {
        final failure? => ruleLogoFailureText(l10n, failure),
        null => null,
      },
      child: Row(
        children: [
          InstitutionAvatar(
            key: const Key('ruleFormLogoPreview'),
            name: name,
            size: _previewSize,
            logo: logo,
            zoomable: true,
          ),
          const SizedBox(width: AppSpacing.md),
          if (ruleId != null)
            // Wraps rather than overflows: the French labels run long.
            Flexible(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    key: const Key('ruleFormLogoChoose'),
                    onPressed: state.busy ? null : pick,
                    child: Text(
                      logo == null
                          ? l10n.ruleFormLogoChoose
                          : l10n.ruleFormLogoReplace,
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('ruleFormLogoFromUrl'),
                    onPressed: state.busy ? null : fromUrl,
                    child: Text(l10n.ruleFormLogoFromUrl),
                  ),
                  if (logo != null)
                    // A bin rather than a text button: lighter next to the
                    // two outlined ones; the label stays as the tooltip,
                    // which also gives it its semantic label.
                    IconButton(
                      key: const Key('ruleFormLogoRemove'),
                      onPressed: state.busy
                          ? null
                          : () => controller.remove(ruleId),
                      tooltip: l10n.ruleFormLogoRemove,
                      iconSize: 18,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The localized reason a picture didn't become (or stop being) the logo.
String ruleLogoFailureText(
  AppLocalizations l10n,
  PictureUploadFailure failure,
) => switch (failure) {
  PictureUploadFailure.tooLarge => l10n.ruleLogoTooLarge(
    maxPictureUploadBytes ~/ (1024 * 1024),
  ),
  PictureUploadFailure.invalidType => l10n.ruleLogoInvalid,
  PictureUploadFailure.generic => l10n.ruleLogoError,
};

/// The square crop step between picking a picture and making it the logo.
class _RuleLogoCropModal extends ConsumerWidget {
  const _RuleLogoCropModal({required this.ruleId, required this.image});

  final String ruleId;
  final ui.Image image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(ruleLogoControllerProvider);
    return PictureCropModal(
      image: image,
      title: l10n.ruleLogoCropTitle,
      lead: l10n.ruleLogoCropLead,
      cancelLabel: l10n.ruleLogoCropCancel,
      saveLabel: l10n.ruleLogoCropSave,
      busy: state.busy,
      failureMessage: switch (state.failure) {
        final failure? => ruleLogoFailureText(l10n, failure),
        null => null,
      },
      onSave: (image, crop) => ref
          .read(ruleLogoControllerProvider.notifier)
          .upload(ruleId, image, crop),
    );
  }
}

/// The localized reason a picture couldn't be downloaded from an address.
String ruleLogoDownloadFailureText(
  AppLocalizations l10n,
  PictureDownloadFailure failure,
) => switch (failure) {
  PictureDownloadFailure.invalidAddress => l10n.ruleLogoUrlInvalidAddress,
  PictureDownloadFailure.unreachable => l10n.ruleLogoUrlUnreachable,
  PictureDownloadFailure.tooLarge => l10n.ruleLogoUrlTooLarge(
    maxPictureUploadBytes ~/ (1024 * 1024),
  ),
  PictureDownloadFailure.notAPicture => l10n.ruleLogoUrlNotAPicture,
};

/// Asks for a picture's address and downloads it once the user confirms.
/// Closes with the decoded picture, for the crop step; a refused download
/// keeps it open with the reason.
class _RuleLogoUrlModal extends ConsumerStatefulWidget {
  const _RuleLogoUrlModal();

  @override
  ConsumerState<_RuleLogoUrlModal> createState() => _RuleLogoUrlModalState();
}

class _RuleLogoUrlModalState extends ConsumerState<_RuleLogoUrlModal> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final image = await ref
        .read(ruleLogoUrlControllerProvider.notifier)
        .fetch(_address.text);
    if (image != null && mounted) Navigator.of(context).pop(image);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(ruleLogoUrlControllerProvider);
    final busy = state.busy;
    return AppModal(
      title: l10n.ruleLogoUrlTitle,
      width: 420,
      actions: [
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ruleLogoUrlCancel),
        ),
        PrimaryButton(
          key: const Key('ruleLogoUrlFetch'),
          label: l10n.ruleLogoUrlFetch,
          isLoading: busy,
          onPressed: busy ? null : _fetch,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.ruleLogoUrlLead,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: l10n.ruleLogoUrlLabel,
            child: TextField(
              key: const Key('ruleLogoUrlField'),
              controller: _address,
              autofocus: true,
              enabled: !busy,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: l10n.ruleLogoUrlHint),
              onSubmitted: busy ? null : (_) => _fetch(),
            ),
          ),
          if (state.failure case final failure?) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(message: ruleLogoDownloadFailureText(l10n, failure)),
          ],
        ],
      ),
    );
  }
}
