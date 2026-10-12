import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../application/update_check_controller.dart';
import '../domain/update_status.dart';
import 'engine_plate.dart';

/// « Mises à jour » in Settings › À propos: the opt-in check for a newer
/// release, and what it found.
///
/// Off by default, because it is the one request the app sends beyond this
/// computer; the note under the toggle says exactly what that request carries.
class UpdateCheckCard extends ConsumerWidget {
  const UpdateCheckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(updateCheckControllerProvider);
    final state = async.value;
    final enabled = state?.status.enabled ?? false;

    return AppCard(
      key: const Key('settingsUpdateCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsUpdatesTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settingsUpdatesSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppToggle(
                key: const Key('settingsUpdateToggle'),
                value: enabled,
                // Still while loading, failed, or saving: there is nothing
                // stored to flip yet, or a flip already in flight.
                onChanged: state == null || state.isBusy
                    ? null
                    : (value) => ref
                          .read(updateCheckControllerProvider.notifier)
                          .setEnabled(value),
                semanticLabel: l10n.settingsUpdatesToggleLabel,
              ),
            ],
          ),
          if (async.hasError && state == null) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            _StatusLine(
              key: const Key('settingsUpdateStatus'),
              text: l10n.settingsUpdatesUnavailable,
            ),
          ] else if (state != null && enabled) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            if (state.isBusy)
              _StatusLine(
                key: const Key('settingsUpdateStatus'),
                text: l10n.settingsUpdatesChecking,
              )
            else
              _Result(status: state.status),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            l10n.settingsUpdatesNote,
            style: AppTextStyles.helper.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// What the last check found: a newer release with its download link, the
/// latest one already, or GitHub out of reach.
class _Result extends StatelessWidget {
  const _Result({required this.status});

  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final latest = status.latestVersion;
    final url = status.releaseUrl;

    // A newer release found earlier is still worth showing when today's check
    // could not reach GitHub.
    if (status.updateAvailable && latest != null && url != null) {
      return EnginePlate(
        key: const Key('settingsUpdateAvailable'),
        icon: Icons.system_update_alt_rounded,
        title: l10n.settingsUpdatesAvailable(latest),
        caption: l10n.settingsUpdatesCurrent(status.currentVersion),
        trailing: SizedBox(
          height: 34,
          child: OutlinedButton(
            key: const Key('settingsUpdateDownload'),
            onPressed: () =>
                launchUrl(url, mode: LaunchMode.externalApplication),
            child: Text(l10n.settingsUpdatesDownload),
          ),
        ),
      );
    }
    if (!status.reachable) {
      return _StatusLine(
        key: const Key('settingsUpdateStatus'),
        text: l10n.settingsUpdatesOffline,
      );
    }
    return _StatusLine(
      key: const Key('settingsUpdateStatus'),
      icon: Icons.check_rounded,
      text: l10n.settingsUpdatesUpToDate(status.currentVersion),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    return Row(
      children: [
        if (icon case final icon?) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
