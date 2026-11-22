import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/l10n/date_display.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/inspector_pane.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/key_value_list.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account.dart';
import '../../imports/presentation/imports_screen.dart';
import '../../recurring/domain/recurring_series.dart';
import '../../recurring/presentation/mark_recurring_dialog.dart';
import '../../recurring/presentation/recurring_labels.dart';
import '../../rules/application/rules_controller.dart';
import '../../rules/presentation/rule_editor_modal.dart';
import '../application/transaction_selection.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';
import 'always_categorize_modal.dart';
import 'category_picker.dart';
import 'transaction_labels.dart';
import 'transactions_link.dart';

/// The inspector pane of the « Toutes » tab (`07-transactions.md` §Inspector
/// pane) for the selected operation: its header, amount and key/value list,
/// its recurring series, the merchant's earlier operations, and the rule
/// action.
class TransactionInspector extends ConsumerWidget {
  const TransactionInspector({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contextAsync = ref.watch(transactionContextProvider(transaction.id));
    final details = contextAsync.value;

    return InspectorPane(
      key: const Key('transactionInspector'),
      selection: transaction.id,
      blocks: [
        _Summary(transaction: transaction, details: details),
        if (contextAsync.hasError && details == null)
          NoteLine(
            key: const Key('transactionInspectorError'),
            icon: LucideIcons300.triangleAlert,
            text: l10n.transactionInspectorLoadError,
          )
        else ...[
          if (details?.series case final series?)
            _RecurringRow(series: series)
          else if (details != null && transaction.amountMinor < 0)
            _MarkRecurring(transaction: transaction),
          if (details != null)
            _History(transaction: transaction, details: details),
        ],
      ],
    );
  }
}

/// The pane with nothing selected: its ground and the note.
class EmptyTransactionInspector extends StatelessWidget {
  const EmptyTransactionInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Container(
      key: const Key('transactionInspectorEmpty'),
      width: AppSizes.inspector,
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: colors.rail,
        border: Border(left: BorderSide(color: colors.line)),
      ),
      child: NoteLine(text: l10n.transactionInspectorEmpty),
    );
  }
}

/// Blocks 1 to 3: the header, the amount at 28 px, and the key/value list.
class _Summary extends ConsumerWidget {
  const _Summary({required this.transaction, required this.details});

  final Transaction transaction;
  final TransactionContext? details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final accounts =
        ref.watch(accountsControllerProvider).value ?? const <Account>[];
    final account = accounts
        .where((account) => account.id == transaction.accountId)
        .firstOrNull;
    final unnamed = isUnnamed(transaction);
    final fileName = details?.importFileName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InstitutionAvatar(
              name: unnamed ? '' : transactionName(transaction),
              size: MonogramAvatar.large,
              logo: transaction.logo,
            ),
            const SizedBox(width: AppSpacing.smPlus),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transactionName(transaction),
                    key: const Key('transactionInspectorName'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: unnamed ? AppFonts.mono : null,
                    ),
                  ),
                  if (!unnamed)
                    Text(
                      transaction.descriptionRaw,
                      key: const Key('transactionInspectorRaw'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: InspectorPane.blockGap),
        AmountText(
          key: const Key('transactionInspectorAmount'),
          amountMinor: transaction.amountMinor,
          currency: transaction.currency,
          showPositiveSign: true,
          style: tabularNumberStyle(textTheme.displayMedium!),
        ),
        const SizedBox(height: InspectorPane.blockGap),
        KeyValueList(
          entries: [
            KeyValue(
              l10n.transactionInspectorDate,
              DayMonthFormat.yMMMMd(locale).format(transaction.bookedDate),
            ),
            KeyValue(l10n.transactionInspectorAccount, account?.name ?? '—'),
            KeyValue.widget(
              l10n.transactionInspectorCategory,
              _CategorySelect(transaction: transaction),
              key: const Key('transactionInspectorCategory'),
            ),
            KeyValue.widget(
              l10n.transactionInspectorClassifiedBy,
              Text(
                classifiedByLabel(l10n, transaction, details),
                key: const Key('transactionInspectorClassifiedBy'),
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            KeyValue.widget(
              l10n.transactionInspectorImport,
              fileName == null
                  ? Text('—', style: TextStyle(color: colors.textSecondary))
                  : TransactionsLink(
                      key: const Key('transactionInspectorImport'),
                      label: fileName,
                      small: false,
                      mono: true,
                      onTap: () => context.go(ImportsScreen.path),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The 28 px select showing the full category label (`07` §Inspector pane);
/// it opens the category picker. Choosing clears the review flag.
class _CategorySelect extends ConsumerStatefulWidget {
  const _CategorySelect({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_CategorySelect> createState() => _CategorySelectState();
}

class _CategorySelectState extends ConsumerState<_CategorySelect> {
  bool _hovered = false;
  bool _focused = false;

  void _open() =>
      showCategoryPicker(context, ref, transaction: widget.transaction);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      child: GestureDetector(
        key: const Key('transactionInspectorCategorySelect'),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: FocusRing(
          focused: _focused,
          radius: AppRadii.control,
          child: Container(
            height: AppSizes.toolbarSelect,
            constraints: const BoxConstraints(
              maxWidth: AppTransactions.pickerWidth,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: _hovered ? colors.hover : colors.field,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: colors.lineStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TransactionCategoryLabel(
                    category: widget.transaction.category,
                    full: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.xsPlus),
                Icon(
                  LucideIcons300.chevronDown,
                  size: AppSizes.iconSmall,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `repeat` · « Paiement récurrent » over its cadence and next date · « Voir
/// la série ».
class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.series});

  final TransactionSeriesRef series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      key: const Key('transactionInspectorRecurring'),
      children: [
        Icon(
          LucideIcons300.repeat,
          size: AppSizes.iconSmall,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.transactionRecurringTitle, style: textTheme.bodyMedium),
              Text(
                l10n.transactionRecurringNext(
                  cadenceLabel(l10n, Cadence.fromWire(series.cadence)),
                  DayMonthFormat.yMMMd(locale).format(series.nextExpectedDate),
                ),
                style: tabularNumberStyle(
                  textTheme.bodySmall!,
                ).copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TransactionsLink(
          key: const Key('transactionInspectorViewSeries'),
          label: l10n.transactionRecurringView,
          onTap: () => openRecurringSeries(context, ref, seriesId: series.id),
        ),
      ],
    );
  }
}

/// A charge in no series: the ghost « Marquer comme récurrent », which opens
/// the existing dialog. Inflows have no such action (a subscription is paid).
class _MarkRecurring extends ConsumerWidget {
  const _MarkRecurring({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppButton(
        key: const Key('transactionInspectorMarkRecurring'),
        label: l10n.markRecurringAction,
        icon: LucideIcons300.repeat,
        variant: AppButtonVariant.ghost,
        onPressed: () => showMarkRecurringDialog(
          context,
          ref,
          transactionId: transaction.id,
        ),
      ),
    );
  }
}

/// « Même marchand » and up to five earlier operations, then the rule action
/// at the foot of the pane.
class _History extends ConsumerWidget {
  const _History({required this.transaction, required this.details});

  final Transaction transaction;
  final TransactionContext details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final rule = details.rule;

    return Column(
      key: const Key('transactionInspectorHistory'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: l10n.transactionSameMerchant),
        const SizedBox(height: AppSpacing.sm),
        if (details.sameMerchant.isEmpty)
          Text(
            l10n.transactionSameMerchantNone,
            key: const Key('transactionInspectorSameMerchantNone'),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          )
        else
          for (final operation in details.sameMerchant)
            Padding(
              key: Key('transactionInspectorSameMerchant-${operation.id}'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DayMonthFormat.yMMMd(locale).format(operation.bookedDate),
                      style: tabularNumberStyle(
                        textTheme.bodyMedium!,
                      ).copyWith(color: colors.textSecondary),
                    ),
                  ),
                  AmountText(
                    amountMinor: operation.amountMinor,
                    currency: operation.currency,
                    showPositiveSign: true,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: rule == null
              ? AppButton(
                  key: const Key('transactionInspectorCreateRule'),
                  label: l10n.transactionCreateRule,
                  onPressed: () => _createRule(context),
                )
              : AppButton(
                  key: const Key('transactionInspectorEditRule'),
                  label: l10n.transactionEditRule,
                  onPressed: () => _editRule(context, ref, rule.id),
                ),
        ),
      ],
    );
  }

  Future<void> _createRule(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    final result = await showAlwaysCategorizeModal(
      context,
      transaction: transaction,
    );
    if (result == null) return;
    showAppToastOn(
      overlay,
      title: l10n.alwaysRuleCreatedToast(result.recategorizedCount),
    );
  }

  /// Opens the rule that filed the row in the rules panel's editor.
  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref,
    String ruleId,
  ) async {
    final rules = await ref.read(rulesControllerProvider.future);
    final rule = rules.where((rule) => rule.id == ruleId).firstOrNull;
    if (rule == null || !context.mounted) return;
    final saved = await showRuleEditor(context, initial: rule);
    if (saved != null) ref.read(transactionEditsProvider.notifier).saved();
  }
}
