import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_link.dart';
import '../../../core/widgets/app_table.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/repere_meter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../categorization/application/run_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'ai_run_banner.dart';
import 'always_categorize_modal.dart';
import 'category_picker.dart';
import 'transaction_error_localizer.dart';
import 'transaction_labels.dart';

/// The « À vérifier » tab (`07-transactions.md` §Tab « À vérifier »): the
/// progress row (or the run's banner), then the queue as a table whose rows
/// confirm, correct or learn a rule from each proposal. Nothing is filed
/// without the user's say.
///
/// Stateful for one reason: the progress needs a *baseline* to count against,
/// and the API only reports what is still unreviewed. The largest queue seen
/// this session is that baseline, so filing a row moves the repère instead of
/// shrinking the only number on screen.
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
    // Grows when an import or a run adds rows; never shrinks, because a filed
    // row is progress, not a smaller job.
    _baseline = math.max(_baseline, widget.total);
  }

  static List<AppTableColumn> _columns(AppLocalizations l10n) => [
    AppTableColumn(label: l10n.reviewColumnLabel, flex: 4),
    AppTableColumn(
      label: l10n.reviewColumnDate,
      width: AppTransactions.reviewDateColumn,
      numeric: true,
    ),
    AppTableColumn(label: l10n.reviewColumnProposal, flex: 5),
    const AppTableColumn(
      label: '',
      width: AppTransactions.reviewActionsColumn,
      numeric: true,
    ),
    AppTableColumn(
      label: l10n.transactionsColumnAmount,
      width: AppTransactions.amountColumn,
      numeric: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aiIsActive =
        ref.watch(aiAvailabilityProvider).value?.isActive ?? false;
    final runState = ref.watch(runControllerProvider);
    final run = runState.run;
    final columns = _columns(l10n);
    const rowPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.pageX,
      vertical: AppSpacing.md,
    );

    return Column(
      key: const Key('reviewQueue'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (runState.error != null)
          Padding(
            padding: rowPadding.copyWith(bottom: 0),
            child: InlineBanner(
              key: const Key('reviewRunError'),
              tone: BannerTone.warning,
              message: l10n.runStartFailed,
            ),
          ),
        if (run != null && run.status.isTerminal && !runState.isBannerDismissed)
          Padding(
            padding: rowPadding.copyWith(bottom: 0),
            child: RunOutcomeBanner(run: run),
          ),
        Padding(
          padding: rowPadding,
          // Replaced, not stacked: while a run is classifying, the progress
          // is a moving target and the banner is the truthful one.
          child: runState.isRunning
              ? AiRunBanner(run: run!)
              : _ProgressRow(
                  total: widget.total,
                  baseline: _baseline,
                  proposedCount: widget.items
                      .where((item) => item.hasModelProposal)
                      .length,
                  aiIsActive: aiIsActive,
                  isStarting: runState.isStarting,
                ),
        ),
        Expanded(
          child: widget.items.isEmpty
              ? EmptyStateView(
                  key: const Key('reviewQueueEmpty'),
                  title: l10n.reviewEmptyTitle,
                  message: l10n.reviewEmptyBody,
                )
              : ListView(
                  key: const Key('reviewQueueList'),
                  children: [
                    AppTableHeader(columns: columns, inset: edgeTableInset),
                    for (final transaction in widget.items)
                      _ReviewRow(
                        key: Key('reviewRow-${transaction.id}'),
                        transaction: transaction,
                        columns: columns,
                        hasProposal: aiIsActive && transaction.hasModelProposal,
                      ),
                    if (!aiIsActive)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageX,
                          vertical: AppSpacing.md,
                        ),
                        child: _AiInvitation(),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Left, 260 px: « 4 sur 16 classées » over a repère without
/// mark. Right, when local AI is on: the Note (`cpu`) and the run's start.
class _ProgressRow extends ConsumerWidget {
  const _ProgressRow({
    required this.total,
    required this.baseline,
    required this.proposedCount,
    required this.aiIsActive,
    required this.isStarting,
  });

  final int total;
  final int baseline;
  final int proposedCount;
  final bool aiIsActive;

  /// A start request is in flight: the button spins rather than the row
  /// swapping twice.
  final bool isStarting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final done = math.max(0, baseline - total);
    final fraction = baseline == 0 ? 1.0 : done / baseline;

    return Row(
      key: const Key('reviewProgressRow'),
      children: [
        SizedBox(
          width: AppTransactions.progressWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.reviewProgressCount(done, baseline),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: ' ${l10n.reviewProgressCaption}',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
                key: const Key('reviewProgressLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tabularNumberStyle(textTheme.bodyMedium!),
              ),
              const SizedBox(height: AppSpacing.xsPlus),
              RepereMeter(
                fraction: fraction,
                semanticLabel: l10n.reviewProgressCount(done, baseline),
              ),
            ],
          ),
        ),
        if (aiIsActive) ...[
          // The free width goes before the Note, never after the button: the
          // pair hugs the row's end edge with the Note right beside the
          // button, however short the Note's text or wide the window.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTransactions.noteMaxWidth,
                ),
                child: NoteLine(
                  key: const Key('reviewAiNote'),
                  icon: LucideIcons300.cpu,
                  text: l10n.reviewAiNote(proposedCount),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            key: const Key('reviewQueueRunButton'),
            label: l10n.reviewQueueRunAction,
            icon: LucideIcons300.cpu,
            isLoading: isStarting,
            onPressed: isStarting
                ? null
                : () =>
                      ref.read(runControllerProvider.notifier).startFromQueue(),
          ),
        ],
      ],
    );
  }
}

/// Under the table when local AI is off, the one place the panel mentions it:
/// the Note and its « Paramètres » link.
class _AiInvitation extends StatelessWidget {
  const _AiInvitation();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      key: const Key('reviewAiInvitation'),
      children: [
        Flexible(
          child: NoteLine(
            icon: LucideIcons300.cpu,
            text: l10n.reviewAiInvitation,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppLink(
          key: const Key('reviewAiInvitationLink'),
          label: l10n.reviewAiInvitationLink,
          onTap: () => context.go(SettingsScreen.path),
        ),
      ],
    );
  }
}

/// One queue row: the raw bank label, the date, the proposal (or « Aucune
/// proposition »), the actions, the signed amount.
///
/// Only the row under the pointer or holding the focus shows « Confirmer » as
/// the primary button; the others show it as secondary, so the screen never
/// carries a column of primaries.
class _ReviewRow extends ConsumerStatefulWidget {
  const _ReviewRow({
    super.key,
    required this.transaction,
    required this.columns,
    required this.hasProposal,
  });

  final Transaction transaction;
  final List<AppTableColumn> columns;
  final bool hasProposal;

  @override
  ConsumerState<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends ConsumerState<_ReviewRow> {
  bool _hovered = false;
  bool _focused = false;
  bool _isConfirming = false;

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    try {
      await ref
          .read(transactionsControllerProvider.notifier)
          .confirmProposal(widget.transaction);
    } catch (error) {
      showAppToastOn(
        overlay,
        title: localizeTransactionError(l10n, error),
        tone: BannerTone.error,
      );
    } finally {
      // The row leaves the queue on the next reload, but stays on screen
      // until then: a button left spinning would read as a confirm that never
      // landed.
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _createRule() async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    final result = await showAlwaysCategorizeModal(
      context,
      transaction: widget.transaction,
    );
    if (result == null) return;
    showAppToastOn(
      overlay,
      title: l10n.alwaysRuleCreatedToast(result.recategorizedCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final transaction = widget.transaction;
    final hot = _hovered || _focused;
    final confidence = transaction.categorizationConfidence;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AppTableRow(
          columns: widget.columns,
          inset: edgeTableInset,
          cells: [
            Text(
              transaction.descriptionRaw,
              key: const Key('reviewRowLabel'),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            Text(
              DayMonthFormat.MMMd(locale).format(transaction.bookedDate),
              style: TextStyle(color: colors.textSecondary),
            ),
            if (widget.hasProposal && confidence != null)
              TransactionCategoryLabel(
                key: const Key('reviewRowProposal'),
                category: transaction.category,
                full: true,
                confidence: l10n.reviewConfidence(confidence),
              )
            else
              Text(
                l10n.reviewNoProposal,
                key: const Key('reviewRowNoProposal'),
                style: TextStyle(color: colors.textTertiary),
              ),
            // Scaled down rather than clipped when a narrow window or a long
            // translation runs out of room: the actions stay whole.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.hasProposal) ...[
                    AppButton(
                      key: const Key('reviewRowConfirmButton'),
                      label: l10n.reviewConfirm,
                      icon: LucideIcons300.check,
                      variant: hot
                          ? AppButtonVariant.primary
                          : AppButtonVariant.secondary,
                      isLoading: _isConfirming,
                      onPressed: _confirm,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Builder(
                      builder: (anchor) => AppButton(
                        key: const Key('reviewRowCorrectButton'),
                        label: l10n.reviewCorrect,
                        onPressed: _isConfirming
                            ? null
                            : () => showCategoryPicker(
                                anchor,
                                ref,
                                transaction: transaction,
                              ),
                      ),
                    ),
                  ] else
                    Builder(
                      builder: (anchor) => AppButton(
                        key: const Key('reviewRowChooseCategory'),
                        label: l10n.reviewChooseCategory,
                        onPressed: () => showCategoryPicker(
                          anchor,
                          ref,
                          transaction: transaction,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Tooltip(
                    message: l10n.reviewAlwaysCategorize,
                    child: AppButton(
                      key: const Key('reviewRowAlwaysButton'),
                      label: l10n.transactionCreateRule,
                      icon: LucideIcons300.wandSparkles,
                      variant: AppButtonVariant.ghost,
                      onPressed: _createRule,
                    ),
                  ),
                ],
              ),
            ),
            AmountText(
              amountMinor: transaction.amountMinor,
              currency: transaction.currency,
              showPositiveSign: true,
            ),
          ],
        ),
      ),
    );
  }
}
