import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/search_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_search.dart';
import 'account_form.dart';

/// The accounts panel's contribution to the top bar: search, then the primary
/// add action.
///
/// It lives with the feature rather than in the shell so the panel owns its own
/// controls, and it is a [ConsumerWidget] so it can drive the query provider
/// without the shell knowing anything about accounts.
class AccountsTopBarActions extends ConsumerWidget {
  const AccountsTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchPill(
          key: const Key('accountsSearchField'),
          hint: l10n.accountsSearchHint,
          initialValue: ref.read(accountsQueryProvider),
          onChanged: (value) => ref.read(accountsQueryProvider.notifier).set(value),
        ),
        const SizedBox(width: 12),
        PrimaryButton(
          key: const Key('addAccountButton'),
          label: l10n.accountsAddButton,
          icon: Icons.add_rounded,
          onPressed: () => showAccountForm(context),
        ),
      ],
    );
  }
}
