import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/update_status.dart';

/// Everything the « Mises à jour » card renders.
@immutable
class UpdateCheckState {
  const UpdateCheckState({
    required this.status,
    this.isBusy = false,
    this.isChecking = false,
  });

  final UpdateStatus status;

  /// The toggle's patch, or the check that follows it, is in flight. The card
  /// keeps the toggle still meanwhile, so a second tap can't race the first.
  final bool isBusy;

  /// The busy work is « Vérifier maintenant »: its button shows the spinner.
  final bool isChecking;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpdateCheckState &&
          other.status == status &&
          other.isBusy == isBusy &&
          other.isChecking == isChecking);

  @override
  int get hashCode => Object.hash(status, isBusy, isChecking);
}

/// Loads the update status when Settings › À propos opens, and turns the
/// opt-in check on or off.
///
/// The backend owns the once-a-day limit, so reading the status here is
/// always cheap: it reaches GitHub only when a check is due. « Vérifier
/// maintenant » is the one explicit check that skips it.
class UpdateCheckController extends AsyncNotifier<UpdateCheckState> {
  @override
  Future<UpdateCheckState> build() async => UpdateCheckState(
    status: await ref.read(settingsRepositoryProvider).updateStatus(),
  );

  /// Opts in or out, then reads the status again: turning the check on is
  /// what makes the first one run.
  Future<void> setEnabled(bool enabled) async {
    final current = state.value;
    if (current == null || current.isBusy) return;

    state = AsyncData(UpdateCheckState(status: current.status, isBusy: true));
    final repository = ref.read(settingsRepositoryProvider);
    try {
      await repository.update(updateCheckEnabled: enabled);
    } catch (_) {
      // Not saved: the toggle falls back to what is stored rather than showing
      // a choice that was never made.
      state = AsyncData(UpdateCheckState(status: current.status));
      return;
    }
    UpdateStatus status;
    try {
      status = await repository.updateStatus();
    } catch (_) {
      // Saved, but the status could not be read back: show the saved choice
      // with nothing checked yet; the next visit reads it again.
      status = UpdateStatus(
        enabled: enabled,
        currentVersion: current.status.currentVersion,
      );
    }
    state = AsyncData(UpdateCheckState(status: status));
  }

  /// « Vérifier maintenant »: asks GitHub now, whatever the daily limit. The
  /// backend reuses a check under a minute old, so repeated taps stay local.
  Future<void> checkNow() async {
    final current = state.value;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      UpdateCheckState(status: current.status, isBusy: true, isChecking: true),
    );
    try {
      final status = await ref
          .read(settingsRepositoryProvider)
          .checkForUpdates();
      state = AsyncData(UpdateCheckState(status: status));
    } catch (_) {
      // Nothing new could be read: keep what was shown.
      state = AsyncData(UpdateCheckState(status: current.status));
    }
  }
}

final updateCheckControllerProvider =
    AsyncNotifierProvider<UpdateCheckController, UpdateCheckState>(
      UpdateCheckController.new,
    );
