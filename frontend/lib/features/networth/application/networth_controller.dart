import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/networth_repository.dart';
import '../domain/networth_summary.dart';

/// The Synthèse summary: read-only, re-read whole whenever something it sums
/// changes.
///
/// Never patched locally. A property write invalidates it (see
/// `PropertiesController`) so the figure follows in the same interaction,
/// computed by the server rather than adjusted from the rows the panel holds.
class NetworthController extends AsyncNotifier<NetWorthSummary> {
  @override
  Future<NetWorthSummary> build() =>
      ref.watch(networthRepositoryProvider).summary();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(networthRepositoryProvider).summary(),
    );
  }
}

final networthControllerProvider =
    AsyncNotifierProvider<NetworthController, NetWorthSummary>(
      NetworthController.new,
    );

/// The two views the panel's segmented control switches between.
enum NetworthView { summary, properties }

/// Which view the panel shows. Panel state rather than a route: both views
/// share the chrome and the « Nouveau bien » control.
class NetworthViewController extends Notifier<NetworthView> {
  @override
  NetworthView build() => NetworthView.summary;

  void set(NetworthView view) => state = view;
}

final networthViewProvider =
    NotifierProvider<NetworthViewController, NetworthView>(
      NetworthViewController.new,
    );
