import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reset_controller.dart';
import 'refusal_banner.dart';
import 'reset_confirm_modal.dart';
import 'reset_format.dart';

/// The « Zone de danger » card in Settings › Données
/// (`docs/design/09-settings.md` §Zone de danger, states ⑩–⑪).
///
/// The only red-bordered card in the app, and the red stops at the border: the
/// button is an outline, and the solid destructive fill appears once, in the
/// confirmation this card can only open.
class DangerZoneCard extends ConsumerWidget {
  const DangerZoneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final failure = ref.watch(resetControllerProvider).failure;

    return AppCard(
      key: const Key('settingsDangerZoneCard'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      border: Border.all(color: AppColors.negative.withValues(alpha: 0.28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsResetTitle, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settingsResetSubtitle,
                      style: AppTextStyles.helper.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ResetButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ResetConfirmModal(),
                ),
              ),
            ],
          ),
          // ⑪ rules: a refused reset is reported here, not in the modal — the
          // modal has closed, and nothing was deleted.
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            RefusalBanner(
              key: const Key('settingsResetError'),
              lead: l10n.settingsResetFailedLead,
              message: resetFailureMessage(l10n, failure),
            ),
          ],
        ],
      ),
    );
  }
}

/// The outline danger button. Its own widget rather than a themed
/// [OutlinedButton] because the danger outline is used exactly here; adding it
/// to the button theme would invite it onto cards that should not carry red.
class _ResetButton extends StatefulWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          key: const Key('settingsResetButton'),
          height: 34,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.negative.withValues(alpha: 0.10) : null,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: AppColors.negative.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.negative,
              ),
              const SizedBox(width: AppSpacing.sm - 1),
              Text(
                AppLocalizations.of(context)!.settingsResetButton,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.negative),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
