import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_layout.dart';
import '../domain/account_group.dart';
import 'account_form.dart';

/// The accounts panel's title-bar controls (`docs/design/05-accounts.md`
/// §Title bar): the « Par type · Par établissement » segmented, then the
/// primary « Ajouter un compte ».
///
/// It lives with the feature rather than in the shell so the panel owns its own
/// controls.
class AccountsTopBarActions extends ConsumerWidget {
  const AccountsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final grouping = ref.watch(
      accountsLayoutProvider.select((layout) => layout.grouping),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSegmented<AccountsGrouping>(
          key: const Key('accountsGroupingSwitch'),
          value: grouping,
          segments: [
            AppSegment(
              key: const Key('accountsGroupingByType'),
              value: AccountsGrouping.byType,
              label: l10n.accountsGroupByType,
            ),
            AppSegment(
              key: const Key('accountsGroupingByInstitution'),
              value: AccountsGrouping.byInstitution,
              label: l10n.accountsGroupByInstitution,
            ),
          ],
          onChanged: ref.read(accountsLayoutProvider.notifier).setGrouping,
        ),
        const SizedBox(width: AppSpacing.sm),
        PrimaryButton(
          key: const Key('addAccountButton'),
          label: l10n.accountsAddButton,
          icon: LucideIcons300.plus,
          onPressed: () => showAccountForm(context),
        ),
      ],
    );
  }
}
