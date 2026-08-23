import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/confidence_gauge.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/proposed_category_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../categorization/application/run_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'category_picker.dart';
import 'transaction_error_localizer.dart';

/// The `needs_review=true` queue: an encouraging progress card over rows that
/// let the user confirm or correct each uncertain transaction, framed as
/// progress rather than a backlog — see `docs/design/07-transactions.md` and
/// the ai-categorization skill's human-review step.
///
/// Stateful for one reason: the progress bar needs a *baseline* to count
/// against, and the API only ever reports what is still unreviewed. The
/// highest queue size seen this session is that baseline, so resolving a row
/// moves the bar instead of shrinking the only number on screen.
class ReviewQueue extends ConsumerStatefulWidget {
  const ReviewQueue({super.key, required this.items, required this.total});

  final List<Transaction> items;
  final int total;

  @override
  ConsumerState<ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends ConsumerState<ReviewQueue> {
  late int _baseline = widget.total;

  @override
  void didUpdateWidget(ReviewQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Grows when an import or a run adds rows; never shrinks, because a
    // resolved row is progress, not a smaller job.
    _baseline = math.max(_baseline, widget.total);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aiIsActive =
        ref.watch(aiAvailabilityProvider).value?.isActive ?? false;

    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          l10n.reviewQueueEmpty,
          key: const Key('reviewQueueEmpty'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReviewQueueHeaderCard(
          total: widget.total,
          baseline: _baseline,
          proposedCount: widget.items.where((item) => item.hasModelProposal).length,
          aiIsActive: aiIsActive,
        ),
        const SizedBox(height: AppSpacing.gridGap),
        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              key: const Key('reviewQueueList'),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) =>
                  _ReviewRow(transaction: widget.items[index], aiIsActive: aiIsActive),
            ),
          ),
        ),
      ],
    );
  }
}

/// The iris-tinted card above the queue: how many rows are left, how many the
/// model proposed for, and how far through the session the user is.
///
/// Public so the run banner can replace it — `docs/design/07` frame ⑦ swaps
/// this whole card out while a run is classifying rather than stacking a
/// second header above it.
class ReviewQueueHeaderCard extends StatelessWidget {
  const ReviewQueueHeaderCard({
    super.key,
    required this.total,
    required this.baseline,
    required this.proposedCount,
    required this.aiIsActive,
  });

  final int total;
  final int baseline;
  final int proposedCount;
  final bool aiIsActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolved = math.max(0, baseline - total);
    final fraction = baseline == 0 ? 1.0 : resolved / baseline;

    return AppCard(
      key: const Key('reviewQueueHeaderCard'),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      gradient: AppColors.irisTintGradient,
      border: Border.all(color: AppColors.irisBorderStrong),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.irisSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: AppColors.iris,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reviewQueueCount(total),
                      key: const Key('reviewQueueCount'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      aiIsActive
                          ? l10n.reviewQueueAiSubtitle(proposedCount)
                          : l10n.reviewQueueEncouragement,
                      key: const Key('reviewQueueSubtitle'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          _ProgressBar(fraction: fraction),
          const SizedBox(height: AppSpacing.sm - 2),
          Text(
            l10n.reviewQueueProgress(resolved, baseline, fraction),
            key: const Key('reviewQueueProgressLabel'),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (!aiIsActive) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            const _AiInvitation(),
          ],
        ],
      ),
    );
  }
}

/// The 6px iris-gradient progress bar the design draws under the headline.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.irisDeep, AppColors.iris],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
        ),
      ),
    );
  }
}

/// The one place in the app that mentions local AI to a user who hasn't turned
/// it on. Deliberately an invitation on an info tint, not a warning: an absent
/// runtime is the expected default state (ai-categorization skill).
class _AiInvitation extends StatelessWidget {
  const _AiInvitation();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      key: const Key('reviewAiInvitation'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 15, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.reviewAiInvitation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.info),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _InlineLink(
            key: const Key('reviewAiInvitationLink'),
            label: l10n.reviewAiInvitationLink,
            onTap: () => context.go(SettingsScreen.path),
          ),
        ],
      ),
    );
  }
}

/// An iris text link sized for a row — the design's « Choisir une catégorie »
/// and « Paramètres » affordances.
class _InlineLink extends StatelessWidget {
  const _InlineLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.iris),
        ),
      ),
    );
  }
}

/// One queue row. Three shapes, decided by [Transaction.hasModelProposal] and
/// whether stage 2 is available at all:
///
/// * a proposal → the dashed proposed chip, its confidence, Confirmer/Corriger;
/// * no proposal, AI on → the neutral chip, « — aucune proposition », and the
///   picker link, so the row says the model was asked and had nothing;
/// * AI off → exactly the Phase 1 row, with no trace of stage 2 anywhere.
class _ReviewRow extends ConsumerWidget {
  const _ReviewRow({required this.transaction, required this.aiIsActive});

  final Transaction transaction;
  final bool aiIsActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasProposal = aiIsActive && transaction.hasModelProposal;

    return Container(
      key: Key('reviewRow-${transaction.id}'),
      constraints: BoxConstraints(minHeight: hasProposal ? 66 : 64),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          InstitutionAvatar(name: transaction.descriptionRaw, size: 36),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(child: _Label(transaction: transaction, showDate: hasProposal)),
          const SizedBox(width: AppSpacing.sm),
          if (hasProposal)
            _ProposalBlock(transaction: transaction)
          else
            _NoProposalBlock(transaction: transaction, aiIsActive: aiIsActive),
          const SizedBox(width: AppSpacing.sm),
          Builder(
            builder: (buttonContext) => _InlineLink(
              key: const Key('reviewRowAlwaysButton'),
              label: l10n.reviewAlwaysCategorize,
              onTap: () => showCategoryPicker(
                buttonContext,
                ref,
                transaction: transaction,
                alwaysRule: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                amountMinor: transaction.amountMinor,
                currency: transaction.currency,
                showPositiveSign: true,
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.transaction, required this.showDate});

  final Transaction transaction;

  /// The booked date under the raw label, which frame ⑥ draws only on the
  /// amended (proposal-bearing) row.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          transaction.descriptionRaw,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono),
        ),
        if (showDate) ...[
          const SizedBox(height: 2),
          Text(
            DateFormat.yMd(locale).format(transaction.bookedDate),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ],
    );
  }
}

/// The chip + gauge + actions that a proposed row carries.
class _ProposalBlock extends ConsumerStatefulWidget {
  const _ProposalBlock({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_ProposalBlock> createState() => _ProposalBlockState();
}

class _ProposalBlockState extends ConsumerState<_ProposalBlock> {
  bool _isConfirming = false;

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(transactionsControllerProvider.notifier)
          .confirmProposal(widget.transaction);
      // The row normally leaves the queue on the next list rebuild, but it is
      // still on screen until then — a button left spinning would read as a
      // confirm that never landed.
      if (mounted) setState(() => _isConfirming = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizeTransactionError(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final category = widget.transaction.category!;
    final slug = categorySlugFor(name: category.name, kind: category.kind);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProposedCategoryChip(
          key: const Key('reviewRowProposedChip'),
          label: localizedCategoryName(l10n, category.name),
          slug: slug,
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        ConfidenceGauge(
          key: const Key('reviewRowConfidenceGauge'),
          confidence: widget.transaction.categorizationConfidence!,
          label: l10n.reviewConfidence(widget.transaction.categorizationConfidence!),
        ),
        const SizedBox(width: AppSpacing.md),
        PrimaryButton(
          key: const Key('reviewRowConfirmButton'),
          label: l10n.reviewConfirm,
          icon: Icons.check_rounded,
          height: 30,
          isLoading: _isConfirming,
          onPressed: _isConfirming ? null : _confirm,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 30,
          child: Builder(
            builder: (buttonContext) => OutlinedButton(
              key: const Key('reviewRowCorrectButton'),
              onPressed: _isConfirming
                  ? null
                  : () => showCategoryPicker(
                      buttonContext,
                      ref,
                      transaction: widget.transaction,
                    ),
              child: Text(l10n.reviewCorrect),
            ),
          ),
        ),
      ],
    );
  }
}

/// The row the model had nothing to say about. Identical to Phase 1 when
/// stage 2 is unavailable — the queue must not grow AI furniture for a user
/// who has no AI.
class _NoProposalBlock extends ConsumerWidget {
  const _NoProposalBlock({required this.transaction, required this.aiIsActive});

  final Transaction transaction;
  final bool aiIsActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (chipContext) => CategoryChip.uncategorized(
            key: const Key('reviewRowCategoryChip'),
            label: l10n.categoryUncategorized,
            onTap: () => showCategoryPicker(chipContext, ref, transaction: transaction),
          ),
        ),
        if (aiIsActive) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.reviewNoProposal,
            key: const Key('reviewRowNoProposal'),
            style: AppTextStyles.reviewNoProposal,
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Builder(
            builder: (linkContext) => _InlineLink(
              key: const Key('reviewRowChooseCategory'),
              label: l10n.reviewChooseCategory,
              onTap: () =>
                  showCategoryPicker(linkContext, ref, transaction: transaction),
            ),
          ),
        ],
      ],
    );
  }
}
