import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../imports/presentation/imports_screen.dart';
import '../application/accounts_controller.dart';
import '../application/accounts_layout.dart';
import '../domain/account.dart';
import 'account_archive.dart';
import 'account_detail_screen.dart';
import 'account_error_localizer.dart';
import 'account_form.dart';
import 'account_section.dart';
import 'card_settlement_warnings.dart';

/// The Comptes panel (`docs/design/05-accounts.md`): the total line, then one
/// collapsible section per account type, or per institution.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const path = '/accounts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsControllerProvider);

    return Padding(
      key: const Key('screen-accounts'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.pageY,
      ),
      child: switch (accounts) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => _Populated(accounts: value),
        AsyncError(:final error) => ErrorStateView(
          message: localizeAccountError(l10n, error),
          messageKey: const Key('accountsErrorText'),
          retryLabel: l10n.accountsRetry,
          retryKey: const Key('accountsRetryButton'),
          onRetry: () =>
              ref.read(accountsControllerProvider.notifier).refresh(),
        ),
        _ => const _LoadingState(),
      },
    );
  }
}

class _Populated extends ConsumerWidget {
  const _Populated({required this.accounts});

  /// The list as loaded; its identity changes with every fresh read, which is
  /// when the backend recalculated the balances.
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(accountGroupsProvider);
    final layout = ref.watch(accountsLayoutProvider);
    final summary = ref.watch(accountsSummaryProvider);
    final now = ref.watch(accountsClockProvider)();
    final currency = summary?.currency ?? accounts.first.currency;

    return ListView(
      key: const Key('accountsList'),
      children: [
        if (summary != null) _TotalLine(summary: summary, accounts: accounts),
        // A card whose purchases may count twice says so above the sections,
        // where the fix (its settlement account or rule) is one tap away.
        const CardSettlementWarnings(),
        for (final group in groups) ...[
          const SizedBox(height: AppSpacing.section),
          AccountSection(
            group: group,
            open: layout.isOpen(group.id),
            currency: currency,
            month: now,
            onToggle: () => ref
                .read(accountsLayoutProvider.notifier)
                .toggleSection(group.id),
            onOpenAccount: (account) =>
                context.go(AccountDetailScreen.location(account.id)),
            onEditCard: (card) => showAccountForm(context, initial: card),
            onArchiveCard: (card) => confirmArchiveAccount(context, ref, card),
          ),
        ],
      ],
    );
  }
}

/// « Solde total » 12 `textSecondary` over the total at 40 px, neutral; on
/// the same baseline at the right, « {n} comptes · soldes recalculés … ».
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.summary, required this.accounts});

  final AccountsSummary summary;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountsTotalBalanceLabel,
              style: context.textStyles.statLabel,
            ),
            const SizedBox(height: AppSpacing.xs),
            AmountText(
              key: const Key('accountsTotalBalance'),
              amountMinor: summary.totalMinor,
              currency: summary.currency,
              // A total is a standing figure, not an inflow or an outflow.
              colorize: false,
              maxLines: 1,
              style: textTheme.displayLarge!,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _RecalculatedCaption(
            key: const Key('accountsSummaryCaption'),
            count: summary.count,
            accounts: accounts,
          ),
        ),
      ],
    );
  }
}

/// How long ago the balances were recalculated: the backend derives them on
/// every read, so this counts from when the current list arrived. Ticks once
/// a minute while shown.
class _RecalculatedCaption extends ConsumerStatefulWidget {
  const _RecalculatedCaption({
    super.key,
    required this.count,
    required this.accounts,
  });

  final int count;
  final List<Account> accounts;

  @override
  ConsumerState<_RecalculatedCaption> createState() =>
      _RecalculatedCaptionState();
}

class _RecalculatedCaptionState extends ConsumerState<_RecalculatedCaption> {
  late DateTime _readAt = ref.read(accountsClockProvider)();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_RecalculatedCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.accounts, widget.accounts)) {
      _readAt = ref.read(accountsClockProvider)();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = ref.read(accountsClockProvider)().difference(_readAt);
    final ago = elapsed.inMinutes < 60
        ? l10n.accountsAgoMinutes(elapsed.inMinutes.clamp(0, 59))
        : l10n.accountsAgoHours(elapsed.inHours);

    return Text(
      l10n.accountsSummaryCaption(l10n.accountsCount(widget.count), ago),
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
    );
  }
}

/// « Ajoutez votre premier compte », one sentence, the primary « Ajouter un
/// compte » and the secondary « Aller aux imports ».
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      key: const Key('accountsEmptyState'),
      title: l10n.accountsEmptyTitle,
      message: l10n.accountsEmptyBody,
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          PrimaryButton(
            key: const Key('emptyStateAddAccountButton'),
            label: l10n.accountsAddButton,
            icon: LucideIcons300.plus,
            onPressed: () => showAccountForm(context),
          ),
          AppButton(
            key: const Key('emptyStateImportsButton'),
            label: l10n.accountsGoToImports,
            onPressed: () => context.go(ImportsScreen.path),
          ),
        ],
      ),
    );
  }
}

/// The total line and three header-bar silhouettes (`05-accounts.md`
/// §States).
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      key: const Key('accountsLoadingIndicator'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBlock(
            height: AppSpacing.smPlus,
            width: AppAccountSection.subtotalWidth,
          ),
          const SizedBox(height: AppSpacing.xs),
          const SkeletonBlock(
            height: AppSpacing.xxl,
            width: AppAccountSection.subtotalWidth * 2,
          ),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: AppSpacing.section),
            SkeletonBlock(
              key: Key('accountsLoadingSection-$i'),
              height: AppSizes.tableRow + AppSpacing.xxs,
              radius: AppRadii.container,
            ),
          ],
        ],
      ),
    );
  }
}
