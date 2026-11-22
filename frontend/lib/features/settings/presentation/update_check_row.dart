import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/update_check_controller.dart';
import '../domain/update_status.dart';
import 'setting_row.dart';

/// « Mises à jour » in Settings › À propos: the opt-in check for a newer
/// release, and what it found.
///
/// Off by default, because it is the one request the app sends beyond this
/// computer; the row's description says exactly what that request carries.
class UpdateCheckRow extends ConsumerWidget {
  const UpdateCheckRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(updateCheckControllerProvider);
    final state = async.value;
    final enabled = state?.status.enabled ?? false;
    final controller = ref.read(updateCheckControllerProvider.notifier);

    return SettingRow(
      key: const Key('settingsUpdateCard'),
      name: l10n.settingsUpdatesTitle,
      description: l10n.settingsUpdatesNote,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppToggle(
              key: const Key('settingsUpdateToggle'),
              value: enabled,
              // Still while loading, failed, or saving: there is nothing
              // stored to flip yet, or a flip already in flight.
              onChanged: state == null || state.isBusy
                  ? null
                  : controller.setEnabled,
              semanticLabel: l10n.settingsUpdatesToggleLabel,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                l10n.settingsUpdatesSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (async.hasError && state == null)
          StatusText(
            key: const Key('settingsUpdateStatus'),
            label: l10n.settingsUpdatesUnavailable,
          )
        else if (state != null && enabled) ...[
          if (state.isBusy)
            StatusText(
              key: const Key('settingsUpdateStatus'),
              label: l10n.settingsUpdatesChecking,
            )
          else
            _Result(status: state.status),
          AppButton(
            key: const Key('settingsUpdateCheckNow'),
            label: l10n.settingsUpdatesCheckNow,
            isLoading: state.isChecking,
            // Disabled while the toggle saves; while it checks it spins
            // instead, in full colour.
            onPressed: state.isBusy && !state.isChecking
                ? null
                : () => _checkNow(context, ref),
          ),
        ],
      ],
    );
  }
}

/// Runs « Vérifier maintenant » and reports its end in a toast: the status
/// line alone changes too quietly to show that the check is over.
Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  // Looked up before the await: the card may be gone when the check ends.
  final overlay = Overlay.maybeOf(context);
  final outcome = await ref
      .read(updateCheckControllerProvider.notifier)
      .checkNow();
  if (outcome == null || overlay == null || !overlay.mounted) return;
  switch (outcome) {
    case UpdateCheckOutcome.upToDate:
      showAppToastOn(overlay, title: l10n.settingsUpdatesToastLatest);
    case UpdateCheckOutcome.updateAvailable:
      // The controller reports this outcome only with a version to name.
      final latest = ref
          .read(updateCheckControllerProvider)
          .requireValue
          .status
          .latestVersion!;
      showAppToastOn(
        overlay,
        title: l10n.settingsUpdatesToastAvailable(latest),
        tone: BannerTone.info,
      );
    case UpdateCheckOutcome.unreachable:
      showAppToastOn(
        overlay,
        title: l10n.settingsUpdatesToastFailed,
        message: l10n.settingsUpdatesToastOffline,
        tone: BannerTone.error,
      );
    case UpdateCheckOutcome.failed:
      showAppToastOn(
        overlay,
        title: l10n.settingsUpdatesToastFailed,
        message: l10n.settingsUpdatesToastError,
        tone: BannerTone.error,
      );
  }
}

/// What the last check found: a newer release with its download button, the
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
      return Wrap(
        key: const Key('settingsUpdateAvailable'),
        spacing: AppSpacing.smPlus,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusText(
            label: l10n.settingsUpdatesAvailable(latest),
            tone: StatusTone.warning,
          ),
          AppButton(
            key: const Key('settingsUpdateDownload'),
            label: l10n.settingsUpdatesDownload,
            onPressed: () =>
                launchUrl(url, mode: LaunchMode.externalApplication),
          ),
        ],
      );
    }
    if (!status.reachable) {
      return StatusText(
        key: const Key('settingsUpdateStatus'),
        label: l10n.settingsUpdatesOffline,
      );
    }
    return StatusText(
      key: const Key('settingsUpdateStatus'),
      label: l10n.settingsUpdatesLatest,
      icon: LucideIcons300.check,
    );
  }
}
