import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/picture_crop_modal.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goal_image_controller.dart';
import '../application/goals_controller.dart';
import '../domain/goal.dart';
import 'goal_labels.dart';

/// The crop window: the full body width of the 440 px modal (440 − 2 × 24 =
/// 392) at 44:19, so 392 × 169 (proposal v6 `m-frame`, « Recadrage
/// bannière »).
const _bodyWidth = AppModalSizes.w440 - 2 * AppModalSizes.padding;
const _viewport = Size(_bodyWidth, _bodyWidth / AppGoalBanner.aspectRatio);

/// Opens the picker, then the 44:19 crop step, then uploads the result as
/// [goal]'s banner. The avatar's picker and crop, framed for a banner.
///
/// A refused file is reported in the panel's banner; nothing happens when
/// the user cancels.
Future<void> pickGoalImage(
  BuildContext context,
  WidgetRef ref, {
  required Goal goal,
}) async {
  final controller = ref.read(goalImageControllerProvider.notifier);
  final image = await controller.pick();
  if (image == null) {
    if (ref.read(goalImageControllerProvider).failure case final failure?) {
      ref
          .read(goalsControllerProvider.notifier)
          .reportError(GoalImageError(failure));
    }
    return;
  }
  if (!context.mounted) return;
  await showAppModal<void>(
    context: context,
    builder: (_) => GoalImageCropModal(
      image: image,
      onSave: (image, crop) => ref
          .read(goalImageControllerProvider.notifier)
          .upload(goal.id, image, crop),
    ),
  );
}

/// Opens the picker and the crop step for the goal form, which holds the
/// PNG until the goal is saved. Resolves to the cropped bytes, or `null`;
/// a refused file leaves its reason in [goalImageControllerProvider].
Future<Uint8List?> pickGoalImageBytes(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(goalImageControllerProvider.notifier);
  final image = await controller.pick();
  if (image == null || !context.mounted) return null;
  Uint8List? png;
  await showAppModal<void>(
    context: context,
    builder: (_) => GoalImageCropModal(
      image: image,
      onSave: (image, crop) async {
        png = await ref
            .read(goalImageControllerProvider.notifier)
            .crop(image, crop);
        return png != null;
      },
    ),
  );
  return png;
}

/// The 44:19 crop step between picking a picture and making it a banner.
class GoalImageCropModal extends ConsumerWidget {
  const GoalImageCropModal({
    super.key,
    required this.image,
    required this.onSave,
  });

  final ui.Image image;
  final Future<bool> Function(ui.Image image, Rect crop) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(goalImageControllerProvider);
    return PictureCropModal(
      image: image,
      title: l10n.goalImageCropTitle,
      lead: l10n.goalImageCropLead,
      cancelLabel: l10n.goalFormCancel,
      saveLabel: l10n.goalImageCropSave,
      busy: state.busy,
      viewport: _viewport,
      width: AppModalSizes.w440,
      failureMessage: switch (state.failure) {
        final failure? => goalImageFailureText(l10n, failure),
        null => null,
      },
      onSave: onSave,
    );
  }
}
