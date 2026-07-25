import 'package:flutter/material.dart';

import 'monogram_avatar.dart';

/// Institution/merchant avatar.
///
/// No brand-logo source is wired up yet (Phase 1 has no logo field or service —
/// see `docs/design/05-accounts.md`), so this always renders the [MonogramAvatar]
/// fallback. It stays a named widget because it's the single seam a future logo
/// image slots into: every card and row that uses it inherits the logo — and the
/// never-a-broken-image guarantee — for free once one is wired up.
class InstitutionAvatar extends StatelessWidget {
  const InstitutionAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => MonogramAvatar(name: name, size: size);
}
