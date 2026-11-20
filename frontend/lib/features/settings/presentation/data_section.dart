import 'package:flutter/material.dart';

import 'ai_settings_group.dart';
import 'backup_group.dart';
import 'reset_group.dart';

/// Données: IA locale, Sauvegarde, then Réinitialisation last, so the way
/// out (export) is read before the way through.
class DataSection extends StatelessWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [AiSettingsGroup(), BackupGroup(), ResetGroup()],
  );
}
