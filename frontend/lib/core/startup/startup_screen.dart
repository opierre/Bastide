import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../backend/backend_connection.dart';
import '../backend/backend_providers.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/frame_texture.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// What the user sees until the backend is ready, and if it fails.
///
/// Sits on the same ink page as the signed-out screens, under the login
/// lockup, so a normal launch reads as one continuous screen: the lockup stays
/// where it is and the login card appears beneath it.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendControllerProvider);
    final failure = backend.isLoading ? null : backend.error;
    final mismatch = backend.isLoading ? null : backend.value;

    return Scaffold(
      backgroundColor: AppColors.surfaceSunken,
      body: FrameTexture(
        child: CenteredStatePane(
          maxWidth: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLockup.login(),
              const SizedBox(height: AppSpacing.xl),
              if (failure != null)
                _Failed(
                  failure: failure is BackendFailure
                      ? failure
                      : const BackendFailure(BackendFailureKind.crashed),
                  onRetry: () =>
                      ref.read(backendControllerProvider.notifier).retry(),
                  onOpenLogs: () => ref.read(openLogsFolderProvider)(),
                )
              else if (mismatch?.mismatchedAppVersion case final appVersion?)
                _VersionWarning(
                  appVersion: appVersion,
                  backendVersion: mismatch!.version,
                  onRetry: () =>
                      ref.read(backendControllerProvider.notifier).retry(),
                  onContinue: () =>
                      ref.read(versionWarningDismissedProvider.notifier).state =
                          true,
                )
              else
                const _Starting(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      key: const Key('startupLoading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.iris,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Text(
          l10n.startupLoading,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.failure,
    required this.onRetry,
    required this.onOpenLogs,
  });

  final BackendFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, message) = startupFailureText(l10n, failure);

    return _Notice(
      title: title,
      message: message,
      actions: [
        PrimaryButton(
          key: const Key('startupRetry'),
          label: l10n.startupRetry,
          onPressed: onRetry,
        ),
        OutlinedButton(
          key: const Key('startupOpenLogs'),
          onPressed: onOpenLogs,
          child: Text(l10n.startupOpenLogs),
        ),
      ],
    );
  }
}

/// Debug builds only: the backend answering is from another version, most
/// likely a dev backend left running on an older checkout.
class _VersionWarning extends StatelessWidget {
  const _VersionWarning({
    required this.appVersion,
    required this.backendVersion,
    required this.onRetry,
    required this.onContinue,
  });

  final String appVersion;
  final String backendVersion;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Notice(
      title: l10n.startupVersionMismatchTitle,
      message: l10n.startupVersionMismatchDebugMessage(
        appVersion,
        backendVersion,
      ),
      actions: [
        PrimaryButton(
          key: const Key('startupRetry'),
          label: l10n.startupRetry,
          onPressed: onRetry,
        ),
        OutlinedButton(
          key: const Key('startupContinueAnyway'),
          onPressed: onContinue,
          child: Text(l10n.startupContinueAnyway),
        ),
      ],
    );
  }
}

/// The warning plate, title, message and actions shared by the failure and
/// the version warning — the silhouette of [ErrorStateView].
class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlyphPlate(
          icon: Icons.warning_amber_rounded,
          accent: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          key: const Key('startupFailureTitle'),
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          message,
          key: const Key('startupFailureMessage'),
          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm + 2,
          runSpacing: AppSpacing.sm + 2,
          children: actions,
        ),
      ],
    );
  }
}

/// The localized title and message for a startup failure.
(String, String) startupFailureText(
  AppLocalizations l10n,
  BackendFailure failure,
) => switch (failure.kind) {
  BackendFailureKind.notFound => (
    l10n.startupDidNotStartTitle,
    l10n.startupNotFoundMessage,
  ),
  BackendFailureKind.timeout || BackendFailureKind.badHandshake => (
    l10n.startupDidNotStartTitle,
    l10n.startupDidNotStartMessage,
  ),
  BackendFailureKind.unreachable => (
    l10n.startupDidNotStartTitle,
    l10n.startupUnreachableMessage,
  ),
  BackendFailureKind.crashed => (
    l10n.startupCrashedTitle,
    l10n.startupCrashedMessage,
  ),
  BackendFailureKind.schemaTooNew => (
    l10n.startupSchemaTooNewTitle,
    l10n.startupSchemaTooNewMessage,
  ),
  BackendFailureKind.versionMismatch => (
    l10n.startupVersionMismatchTitle,
    l10n.startupVersionMismatchMessage(
      failure.appVersion ?? '?',
      failure.backendVersion ?? '?',
    ),
  ),
};
