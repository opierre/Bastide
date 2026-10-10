import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/local_runtime_controller.dart';
import '../domain/local_runtime.dart';
import 'engine_plate.dart';

/// « Moteur intégré » — the engine Bastide can download for a user with none:
/// its size before anything is fetched, the download's progress, why it
/// stopped, and the way back out (cancel, remove).
///
/// Renders nothing while its status loads, if it cannot be read, or where no
/// build exists for this machine: it is an offer next to the address field,
/// not a part of the card the user needs.
class LocalRuntimePlate extends ConsumerWidget {
  const LocalRuntimePlate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(localRuntimeControllerProvider).value;
    if (runtime == null || runtime.state == LocalRuntimeState.unsupported) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final controller = ref.read(localRuntimeControllerProvider.notifier);
    String size(int bytes) => formatByteSize(bytes, locale, l10n);

    final (caption, captionColor) = switch (runtime.state) {
      LocalRuntimeState.downloading => (
        l10n.settingsAiRuntimeProgress(
          size(runtime.downloadedBytes),
          size(runtime.totalBytes),
        ),
        AppColors.textSecondary,
      ),
      LocalRuntimeState.installed => (
        l10n.settingsAiRuntimeInstalled,
        AppColors.textSecondary,
      ),
      LocalRuntimeState.failed => (
        _errorMessage(l10n, runtime, size),
        AppColors.negative,
      ),
      _ when runtime.canResume => (
        l10n.settingsAiRuntimeResumable(
          size(runtime.downloadedBytes),
          size(runtime.totalBytes),
        ),
        AppColors.textSecondary,
      ),
      _ => (
        l10n.settingsAiRuntimeOffer(size(runtime.totalBytes)),
        AppColors.textSecondary,
      ),
    };

    final Widget trailing = switch (runtime.state) {
      LocalRuntimeState.downloading => _SecondaryButton(
        key: const Key('settingsAiRuntimeCancel'),
        label: l10n.settingsAiRuntimeCancel,
        onPressed: controller.cancel,
      ),
      LocalRuntimeState.installed => _SecondaryButton(
        key: const Key('settingsAiRuntimeRemove'),
        label: l10n.settingsAiRuntimeRemove,
        onPressed: () => _confirmRemove(context, controller),
      ),
      LocalRuntimeState.failed => PrimaryButton(
        key: const Key('settingsAiRuntimeRetry'),
        label: l10n.settingsAiRuntimeRetry,
        height: 34,
        onPressed: controller.download,
      ),
      _ => PrimaryButton(
        key: const Key('settingsAiRuntimeDownload'),
        label: runtime.canResume
            ? l10n.settingsAiRuntimeResume
            : l10n.settingsAiRuntimeDownload,
        height: 34,
        onPressed: controller.download,
      ),
    };

    return EnginePlate(
      key: const Key('settingsAiRuntimePlate'),
      icon: Icons.download_for_offline_outlined,
      title: l10n.settingsAiRuntimeTitle,
      caption: caption,
      captionKey: const Key('settingsAiRuntimeCaption'),
      captionColor: captionColor,
      trailing: trailing,
      footer: runtime.state == LocalRuntimeState.downloading
          ? _DownloadBar(fraction: runtime.fraction)
          : null,
    );
  }

  String _errorMessage(
    AppLocalizations l10n,
    LocalRuntime runtime,
    String Function(int) size,
  ) => switch (runtime.error) {
    LocalRuntimeError.hashMismatch => l10n.settingsAiRuntimeErrorHash,
    LocalRuntimeError.diskFull => l10n.settingsAiRuntimeErrorDisk(
      size(runtime.totalBytes),
    ),
    LocalRuntimeError.extract => l10n.settingsAiRuntimeErrorExtract,
    LocalRuntimeError.network || null => l10n.settingsAiRuntimeErrorNetwork,
  };

  Future<void> _confirmRemove(
    BuildContext context,
    LocalRuntimeController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppModal(
        title: l10n.settingsAiRuntimeRemoveTitle,
        width: 440,
        actions: [
          _SecondaryButton(
            key: const Key('settingsAiRuntimeRemoveCancel'),
            label: l10n.settingsAiRuntimeCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PrimaryButton(
            key: const Key('settingsAiRuntimeRemoveConfirm'),
            label: l10n.settingsAiRuntimeRemove,
            height: 34,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        child: Text(
          l10n.settingsAiRuntimeRemoveBody,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
    if (confirmed ?? false) await controller.remove();
  }
}

/// A byte count in the unit a person reads it in — « 5,2 Go », "5.2 GB".
///
/// Decimal units, like the operating systems' own download dialogs, and the
/// number formatted for [locale] so the separator is the user's own.
String formatByteSize(int bytes, String locale, AppLocalizations l10n) {
  final number = NumberFormat('#,##0.0', locale);
  if (bytes >= 1000 * 1000 * 1000) {
    return l10n.settingsAiRuntimeSizeGb(number.format(bytes / 1e9));
  }
  return l10n.settingsAiRuntimeSizeMb(number.format(bytes / 1e6));
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: OutlinedButton(onPressed: onPressed, child: Text(label)),
  );
}

/// The 6px iris-gradient progress bar, drawn like the categorisation run's so
/// the app has one shape for "work in progress".
class _DownloadBar extends StatelessWidget {
  const _DownloadBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('settingsAiRuntimeProgress'),
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.irisDeep, AppColors.iris],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
        ),
      ),
    );
  }
}
