import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  static const path = '/transactions';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('screen-transactions'),
      icon: Icons.receipt_long_outlined,
      accent: AppColors.info,
      title: l10n.comingSoonTitle,
      message: l10n.comingSoonBody,
    );
  }
}
