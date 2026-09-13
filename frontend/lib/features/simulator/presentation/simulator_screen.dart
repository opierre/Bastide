import 'package:flutter/material.dart';

/// The Simulateur panel (`docs/design/14-simulateur.md`). A placeholder until
/// its panel card lands: the shell already carries the title and descriptor,
/// and the content region stays empty on purpose — no fake data and no "coming
/// soon" copy, so a placeholder shipped by accident looks unfinished, not wrong.
class SimulatorScreen extends StatelessWidget {
  const SimulatorScreen({super.key});

  static const path = '/simulations';

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('screen-simulator'));
}

/// The panel's contribution to the top bar. Registered with the router now so
/// the panel card drops its controls in without touching the router again.
class SimulatorTopBarActions extends StatelessWidget {
  const SimulatorTopBarActions({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
