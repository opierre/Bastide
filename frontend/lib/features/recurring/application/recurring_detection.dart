import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recurring_repository.dart';
import 'subscriptions_controller.dart';

/// Whether a detection pass is in flight, shared by every « Détecter » button
/// the panel shows — the top bar's and the empty state's — so a pass started
/// from one disables the other instead of letting a second one queue up.
class RecurringDetection extends Notifier<bool> {
  @override
  bool build() => false;

  /// Runs detection through [SubscriptionsController.detect] and resolves to
  /// its result, or to `null` when a pass was already running. Failures are
  /// rethrown: the button that asked reports them.
  Future<DetectionResult?> run() async {
    if (state) return null;
    state = true;
    try {
      return await ref.read(subscriptionsControllerProvider.notifier).detect();
    } finally {
      state = false;
    }
  }
}

final recurringDetectionProvider = NotifierProvider<RecurringDetection, bool>(
  RecurringDetection.new,
);
