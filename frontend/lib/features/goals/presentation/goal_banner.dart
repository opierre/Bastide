import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_popover.dart';
import '../../../core/widgets/tomettes.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goals_controller.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import 'goal_image_crop_modal.dart';
import 'goal_labels.dart';

/// The banner at the top of the goal inspector (`11-goals.md` §Inspector
/// pane), edge to edge.
///
/// With an image: the picture cover-cropped, 190 px, a bottom fade carrying
/// the name, the deadline and the percent in fixed whites, and « Changer ».
/// Without one, and while the picture loads or if it fails: 120 px of
/// tomettes on `rail`, the name and the deadline in text tokens, and
/// « Ajouter une image » (or « Changer » when the goal has an image that
/// could not be shown). Never a broken image.
class GoalBanner extends ConsumerWidget {
  const GoalBanner({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageRef = goal.imageRef;
    final bytes = imageRef == null
        ? null
        : ref.watch(goalImageProvider(imageRef)).value;

    return bytes == null
        ? _EmptyBanner(goal: goal)
        : _PictureBanner(goal: goal, bytes: bytes);
  }
}

/// The picture banner. If the bytes don't decode, it turns into the tomettes
/// banner for good, rather than drawing a broken image under the fade.
class _PictureBanner extends StatefulWidget {
  const _PictureBanner({required this.goal, required this.bytes});

  final Goal goal;
  final Uint8List bytes;

  @override
  State<_PictureBanner> createState() => _PictureBannerState();
}

class _PictureBannerState extends State<_PictureBanner> {
  bool _failed = false;

  Goal get goal => widget.goal;

  @override
  void didUpdateWidget(_PictureBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) _failed = false;
  }

  void _fail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _EmptyBanner(goal: goal);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleLarge?.copyWith(
      color: AppGoalBanner.title,
    );

    return SizedBox(
      key: Key('goalBannerImage-${goal.id}'),
      height: AppGoalBanner.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: l10n.goalImageAlt(goal.name),
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) {
                _fail();
                return const SizedBox.shrink();
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: AppGoalBanner.fadeHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppGoalBanner.fade.withValues(alpha: 0),
                    AppGoalBanner.fade,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      Text(
                        goalDeadlineLabel(l10n, locale, goal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppGoalBanner.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus),
                Text(
                  goalPercentLabel(goal.progressPct, locale),
                  key: Key('goalBannerPercent-${goal.id}'),
                  style: titleStyle?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.smPlus,
            right: AppSpacing.smPlus,
            child: _ChangeImageMenu(goal: goal),
          ),
        ],
      ),
    );
  }
}

class _EmptyBanner extends ConsumerWidget {
  const _EmptyBanner({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    return Container(
      key: Key('goalBannerEmpty-${goal.id}'),
      height: AppGoalBanner.heightEmpty,
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Tomettes(fade: TomettesFade.none),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(color: colors.text),
                ),
                Text(
                  goalDeadlineLabel(l10n, locale, goal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.smPlus,
            right: AppSpacing.smPlus,
            child: goal.hasImage
                ? _ChangeImageMenu(goal: goal)
                : AppButton(
                    key: const Key('goalImageAdd'),
                    label: l10n.goalImageAdd,
                    icon: LucideIcons300.imagePlus,
                    onPressed: () => pickGoalImage(context, ref, goal: goal),
                  ),
          ),
        ],
      ),
    );
  }
}

/// « Changer »: a menu to choose another picture or remove this one.
class _ChangeImageMenu extends ConsumerWidget {
  const _ChangeImageMenu({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return MenuAnchor(
      style: AppPopover.menuStyle(context),
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        AppMenuItem(
          key: const Key('goalImageReplace'),
          label: l10n.goalImageReplace,
          leading: const Icon(LucideIcons300.image),
          onPressed: () => pickGoalImage(context, ref, goal: goal),
        ),
        AppMenuItem(
          key: const Key('goalImageRemove'),
          label: l10n.goalImageRemove,
          leading: const Icon(LucideIcons300.imageOff),
          onPressed: () =>
              ref.read(goalsControllerProvider.notifier).removeImage(goal.id),
        ),
      ],
      builder: (context, menu, _) => AppButton(
        key: const Key('goalImageChange'),
        label: l10n.goalImageChange,
        icon: LucideIcons300.image,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
