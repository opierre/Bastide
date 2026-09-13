import 'package:flutter/material.dart';

/// The Impôts panel (`docs/design/13-impots.md`). A placeholder until its
/// panel card lands: the shell already carries the title and descriptor, and
/// the content region stays empty on purpose — no fake data and no "coming
/// soon" copy, so a placeholder shipped by accident looks unfinished, not wrong.
class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  static const path = '/tax';

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('screen-tax'));
}

/// The panel's contribution to the top bar. Registered with the router now so
/// the panel card drops its controls in without touching the router again.
class TaxTopBarActions extends StatelessWidget {
  const TaxTopBarActions({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
