import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';

/// Opens « Historique déclaré »: the month-end totals the user keeps for the
/// time before their imports. [currency] is the user's, for the amount field.
Future<void> showDeclaredBalances(
  BuildContext context, {
  required String currency,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => DeclaredBalancesModal(currency: currency),
  );
}

/// Reads « 03/2025 » (or « 3/2025 ») as the first day of that month, or `null`
/// when it doesn't read as one. The same spelling in both locales: a month
/// has no day to put first or last.
DateTime? parseMonthInput(String raw) {
  final match = RegExp(r'^\s*(\d{1,2})\s*/\s*(\d{4})\s*$').firstMatch(raw);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(2)!), month);
}

/// The inverse, for loading a month back into the field.
String formatMonthInput(DateTime month) =>
    '${month.month.toString().padLeft(2, '0')}/${month.year}';

/// Whether [month] has ended as of [today] — the only months the API accepts.
bool isClosedMonth(DateTime month, DateTime today) =>
    month.year * 12 + month.month < today.year * 12 + today.month;

/// Whether a refused write belongs under the month field.
bool isDeclaredMonthError(Object? error) =>
    error is ApiFailure && error.code == 'DECLARED_MONTH_NOT_CLOSED';

/// Maps the declared-total error `code`s (see
/// `backend/app/features/networth/service.py`) to a localized message.
String localizeDeclaredError(AppLocalizations l10n, Object? error) {
  if (error is ApiFailure) {
    switch (error.code) {
      case 'DECLARED_MONTH_NOT_CLOSED':
        return l10n.networthDeclaredMonthNotClosed;
      case 'DECLARED_BALANCE_NOT_FOUND':
        return l10n.networthDeclaredErrorNotFound;
    }
  }
  return l10n.networthDeclaredErrorGeneric;
}

/// The 560 px list editor (`00` §7, `15-synthese.md` §Modals): an entry row
/// (Mois · Total des comptes · primary « Enregistrer ») that adds or
/// replaces, over the list of what is declared, newest first. The footer has
/// a single « Fermer ».
///
/// A month the imports cover stays listed, dimmed, so the user sees why it is
/// not on the chart rather than wondering where it went.
class DeclaredBalancesModal extends ConsumerStatefulWidget {
  const DeclaredBalancesModal({super.key, required this.currency});

  final String currency;

  @override
  ConsumerState<DeclaredBalancesModal> createState() =>
      _DeclaredBalancesModalState();
}

class _DeclaredBalancesModalState extends ConsumerState<DeclaredBalancesModal> {
  final _formKey = GlobalKey<FormState>();
  final _monthController = TextEditingController();
  final _amountController = TextEditingController();
  final _monthFocus = FocusNode();
  bool _isSubmitting = false;
  String? _monthError;
  String? _bannerError;

  String get _locale => Localizations.localeOf(context).toString();

  @override
  void dispose() {
    _monthController.dispose();
    _amountController.dispose();
    _monthFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final month = parseMonthInput(_monthController.text)!;
    final amount = parseMoneyMinor(
      _amountController.text,
      _locale,
      allowNegative: true,
    )!;
    setState(() {
      _isSubmitting = true;
      _monthError = _bannerError = null;
    });
    try {
      await ref
          .read(declaredBalancesControllerProvider.notifier)
          .declare(month, amount);
      if (!mounted) return;
      _monthController.clear();
      _amountController.clear();
      setState(() => _isSubmitting = false);
      // The fields were out of the focus order while the save ran: back to
      // the entry row's first field once they return, for the next month.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _monthFocus.requestFocus();
      });
    } catch (error) {
      if (!mounted) return;
      _fail(l10n, error);
    }
  }

  Future<void> _remove(DateTime month) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _bannerError = null);
    try {
      await ref.read(declaredBalancesControllerProvider.notifier).remove(month);
    } catch (error) {
      if (mounted) _fail(l10n, error);
    }
  }

  void _fail(AppLocalizations l10n, Object error) {
    final message = localizeDeclaredError(l10n, error);
    setState(() {
      _isSubmitting = false;
      if (isDeclaredMonthError(error)) {
        _monthError = message;
      } else {
        _bannerError = message;
      }
    });
  }

  void _edit(DeclaredBalance entry) {
    setState(() => _monthError = null);
    _monthController.text = formatMonthInput(entry.month);
    _amountController.text = formatMoneyInput(entry.amountMinor, _locale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    final entries = ref.watch(declaredBalancesControllerProvider);

    return AppModal(
      title: l10n.networthDeclaredTitle,
      subtitle: Text(l10n.networthDeclaredSubtitle),
      width: AppModalSizes.w560,
      kind: AppModalKind.listEditor,
      busy: _isSubmitting,
      saveError: _bannerError,
      onSubmit: _submit,
      actions: const [AppModalClose(primary: false)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: _EntryRow(
              monthLabel: l10n.networthDeclaredMonth,
              monthError: _monthError,
              month: TextFormField(
                key: const Key('declaredMonth'),
                controller: _monthController,
                focusNode: _monthFocus,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                ],
                style: tabularNumberStyle(
                  Theme.of(context).textTheme.bodyLarge!,
                ),
                decoration: InputDecoration(
                  hintText: l10n.networthDeclaredMonthHint,
                ),
                validator: (value) {
                  final month = parseMonthInput(value ?? '');
                  if (month == null) {
                    return l10n.networthDeclaredMonthInvalid;
                  }
                  return isClosedMonth(month, DateTime.now())
                      ? null
                      : l10n.networthDeclaredMonthNotClosed;
                },
              ),
              amountLabel: l10n.networthDeclaredAmount,
              amount: MoneyField(
                key: const Key('declaredAmount'),
                controller: _amountController,
                currency: widget.currency,
                // An overdrawn total is a total too.
                allowNegative: true,
                validator: (value) =>
                    parseMoneyMinor(value ?? '', locale, allowNegative: true) ==
                        null
                    ? l10n.networthDeclaredAmountInvalid
                    : null,
              ),
              save: PrimaryButton(
                key: const Key('declaredSave'),
                label: l10n.networthDeclaredSave,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          // The list stays on screen while a write re-reads it.
          entries.when(
            skipLoadingOnReload: true,
            data: (value) => value.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      l10n.networthDeclaredEmpty,
                      key: const Key('declaredEmpty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    key: const Key('declaredList'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, entry) in value.reversed.indexed)
                        _DeclaredRow(
                          entry: entry,
                          locale: locale,
                          first: i == 0,
                          onEdit: () => _edit(entry),
                          onDelete: () => _remove(entry.month),
                        ),
                    ],
                  ),
            error: (_, _) => ModalLoadError(
              message: l10n.networthDeclaredLoadFailed,
              onRetry: () => ref.invalidate(declaredBalancesControllerProvider),
            ),
            // The rows' own silhouette (`00` §7), not a spinner.
            loading: () => const ModalLoadingBody(
              key: Key('declaredLoading'),
              children: [
                SkeletonBlock(height: AppSizes.tableRow),
                SkeletonBlock(height: AppSizes.tableRow),
                SkeletonBlock(height: AppSizes.tableRow),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The entry row: the 130 px month, the total taking the rest, then the
/// primary « Enregistrer », 16 px apart, bottom-aligned with the inputs.
///
/// A [Table], as [ModalFieldRow]: labels, inputs and the server's month error
/// each share a row, so the button stays level with the inputs whatever the
/// labels do, and an error under one field never moves it.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.monthLabel,
    required this.month,
    required this.amountLabel,
    required this.amount,
    required this.save,
    this.monthError,
  });

  final String monthLabel;
  final Widget month;
  final String amountLabel;
  final Widget amount;
  final Widget save;
  final String? monthError;

  static const _labelGap = 5.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
    Widget label(String text) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.bottom,
      child: Padding(
        padding: const EdgeInsets.only(bottom: _labelGap),
        child: Text(text, style: labelStyle),
      ),
    );
    const gutter = SizedBox(width: AppModalSizes.columnGutter);
    const none = SizedBox.shrink();
    final error = monthError;

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(AppNetworth.declaredMonthField),
        1: FixedColumnWidth(AppModalSizes.columnGutter),
        2: FlexColumnWidth(),
        3: FixedColumnWidth(AppModalSizes.columnGutter),
        4: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            label(monthLabel),
            gutter,
            label(amountLabel),
            gutter,
            none,
          ],
        ),
        TableRow(
          children: [
            month,
            gutter,
            amount,
            gutter,
            // The 28 px button ends level with the 32 px inputs.
            Padding(
              padding: const EdgeInsets.only(
                top: AppSizes.formField - AppSizes.button,
              ),
              child: save,
            ),
          ],
        ),
        TableRow(
          children: [
            error == null ? none : FieldHelper(text: error, isError: true),
            gutter,
            none,
            gutter,
            none,
          ],
        ),
      ],
    );
  }
}

/// One declared month (36 px, hairline between rows): « déc. 2024 »,
/// « Couvert par vos imports » when the ledger has it, the neutral total, then
/// the ghost edit and delete. A covered month is dimmed and keeps only
/// delete: its declared figure is no longer used.
class _DeclaredRow extends StatelessWidget {
  const _DeclaredRow({
    required this.entry,
    required this.locale,
    required this.first,
    required this.onEdit,
    required this.onDelete,
  });

  final DeclaredBalance entry;
  final String locale;
  final bool first;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final key = formatMonthInput(entry.month);
    final covered = entry.superseded;
    final ink = covered ? colors.textTertiary : colors.text;
    const cellGap = SizedBox(width: AppSpacing.smPlus);

    return Container(
      key: Key('declaredRow-$key'),
      height: AppSizes.tableRow,
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppNetworth.declaredMonthColumn - AppSpacing.smPlus,
            child: Text(
              DateFormat.yMMM(locale).format(entry.month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: ink),
            ),
          ),
          cellGap,
          Expanded(
            child: covered
                ? Text(
                    l10n.networthDeclaredSuperseded,
                    key: Key('declaredSuperseded-$key'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: ink),
                  )
                : const SizedBox.shrink(),
          ),
          cellGap,
          AmountText(
            amountMinor: entry.amountMinor,
            currency: entry.currency,
            colorize: false,
            style: textTheme.bodyMedium?.copyWith(color: ink),
          ),
          cellGap,
          SizedBox(
            width: AppNetworth.declaredActionsColumn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!covered) ...[
                  AppButton(
                    key: Key('declaredEdit-$key'),
                    label: l10n.networthDeclaredEdit,
                    icon: LucideIcons300.pencil,
                    iconOnly: true,
                    variant: AppButtonVariant.ghost,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                AppButton(
                  key: Key('declaredDelete-$key'),
                  label: l10n.networthDeclaredDelete,
                  icon: LucideIcons300.trash2,
                  iconOnly: true,
                  variant: AppButtonVariant.ghost,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
