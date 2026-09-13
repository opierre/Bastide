import 'package:flutter/material.dart';

/// The Crédits panel (`docs/design/12-credits.md`). A placeholder until its
/// panel card lands: the shell already carries the title and descriptor, and
/// the content region stays empty on purpose — no fake data and no "coming
/// soon" copy, so a placeholder shipped by accident looks unfinished, not wrong.
class MortgagesScreen extends StatelessWidget {
  const MortgagesScreen({super.key});

  static const path = '/mortgages';

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('screen-mortgages'));
}

/// The panel's contribution to the top bar. Registered with the router now so
/// the panel card drops its controls in without touching the router again.
class MortgagesTopBarActions extends StatelessWidget {
  const MortgagesTopBarActions({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
