import 'package:flutter/material.dart';

/// The Synthèse panel (`docs/design/15-synthese.md`). A placeholder until its
/// panel card lands: the shell already carries the title and descriptor, and
/// the content region stays empty on purpose — no fake data and no "coming
/// soon" copy, so a placeholder shipped by accident looks unfinished, not wrong.
class NetworthScreen extends StatelessWidget {
  const NetworthScreen({super.key});

  static const path = '/networth';

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('screen-networth'));
}

/// The panel's contribution to the top bar. Registered with the router now so
/// the panel card drops its controls in without touching the router again.
class NetworthTopBarActions extends StatelessWidget {
  const NetworthTopBarActions({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
