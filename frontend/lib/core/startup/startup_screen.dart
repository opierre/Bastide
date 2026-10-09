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
              if (failure == null)
                const _Starting()
              else
                _Failed(
                  failure: failure is BackendFailure
                      ? failure
                      : const BackendFailure(BackendFailureKind.crashed),
                  onRetry: () =>
                      ref.read(backendControllerProvider.notifier).retry(),
                  onOpenLogs: () => ref.read(openLogsFolderProvider)(),
                ),
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
    final textTheme = Theme.of(context).textTheme;
    final (title, message) = startupFailureText(l10n, failure.kind);

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
          children: [
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
        ),
      ],
    );
  }
}

/// The localized title and message for a startup failure.
(String, String) startupFailureText(
  AppLocalizations l10n,
  BackendFailureKind kind,
) => switch (kind) {
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
  // Until the version check lands, a mismatch reads as a failed start.
  BackendFailureKind.versionMismatch => (
    l10n.startupDidNotStartTitle,
    l10n.startupDidNotStartMessage,
  ),
};
