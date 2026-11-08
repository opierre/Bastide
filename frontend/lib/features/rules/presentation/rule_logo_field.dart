import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pictures/pictures.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/picture_crop_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_logo_controller.dart';
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

    Future<void> pick() async {
      final image = await controller.pick();
      if (image == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RuleLogoCropModal(ruleId: ruleId!, image: image),
      );
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
          ),
          const SizedBox(width: AppSpacing.md),
          if (ruleId != null) ...[
            OutlinedButton(
              key: const Key('ruleFormLogoChoose'),
              onPressed: state.busy ? null : pick,
              child: Text(
                logo == null
                    ? l10n.ruleFormLogoChoose
                    : l10n.ruleFormLogoReplace,
              ),
            ),
            if (logo != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                key: const Key('ruleFormLogoRemove'),
                onPressed: state.busy ? null : () => controller.remove(ruleId),
                child: Text(l10n.ruleFormLogoRemove),
              ),
            ],
          ],
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
