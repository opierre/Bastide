import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../backend/backend_connection.dart';
import '../backend/backend_providers.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/state_views.dart';
import '../widgets/tomettes.dart';

/// What the user sees until the backend is ready, and if it fails
/// (`docs/design/18-brand.md` §4).
///
/// The installer splash's composition, in the window: on tomettes faded
/// behind the column, the Plan mark, the name, the privacy promise, then a
/// status line that can say what is happening, since here text translates.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  /// Mark and name sizes shared with the installer splash.
  static const markSize = 64.0;
  static const nameSize = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final backend = ref.watch(backendControllerProvider);
    final failure = backend.isLoading ? null : backend.error;
    final mismatch = backend.isLoading ? null : backend.value;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: Tomettes()),
          CenteredStatePane(
            maxWidth: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: markSize),
                const SizedBox(height: AppSpacing.md),
                const BrandName(size: nameSize),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.startupPrivacy,
                  key: const Key('startupPrivacy'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.geist,
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                        ref
                                .read(versionWarningDismissedProvider.notifier)
                                .state =
                            true,
                  )
                else
                  const _Starting(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The status line: a 14 px spinner, then « Démarrage du moteur local… ».
class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      key: const Key('startupLoading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.colors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            l10n.startupEngineStarting,
            style: _statusStyle(context.colors.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// The status line's type: 12 px Geist.
TextStyle _statusStyle(Color color) =>
    TextStyle(fontFamily: AppFonts.geist, fontSize: 12, color: color);

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
        OutlinedButton(
          key: const Key('startupRetry'),
          onPressed: onRetry,
          child: Text(l10n.startupRetry),
        ),
        TextButton(
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
        OutlinedButton(
          key: const Key('startupRetry'),
          onPressed: onRetry,
          child: Text(l10n.startupRelaunch),
        ),
        TextButton(
          key: const Key('startupContinueAnyway'),
          onPressed: onContinue,
          child: Text(l10n.startupContinueAnyway),
        ),
      ],
    );
  }
}

/// The status line turned into a failure: what failed in `negative`, the
/// reason under it, then the actions.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          key: const Key('startupFailureTitle'),
          style: _statusStyle(
            context.colors.negative,
          ).copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          key: const Key('startupFailureMessage'),
          style: _statusStyle(context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
