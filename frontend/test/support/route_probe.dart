import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A router showing [home] at `/`, and at `/transactions` a text naming the
/// location reached, so a test can assert where a tap navigated.
GoRouter probeRouter(Widget home) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(body: home),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) =>
          Text(state.uri.toString(), key: const Key('routeProbe')),
    ),
  ],
);

/// The location the probe route shows.
String probedLocation(Widget probe) => (probe as Text).data!;
