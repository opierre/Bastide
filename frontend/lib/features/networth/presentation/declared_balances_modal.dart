import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/networth_controller.dart';
import '../domain/networth_summary.dart';

/// Opens « Historique déclaré »: the month-end totals the user keeps for the
/// time before their imports. [currency] is the user's, for the amount field.
Future<void> showDeclaredBalances(
  BuildContext context, {
  required String currency,
}) {
  return showDialog<void>(
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

/// The 560 px modal: a month + total form that adds or replaces, over the list
/// of what is declared, newest first.
///
/// A month the imports cover stays listed with a chip, so the user sees why it
/// is not on the chart rather than wondering where it went.
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
      _monthFocus.requestFocus();
      setState(() => _isSubmitting = false);
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
      subtitle: Text(
        l10n.networthDeclaredSubtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      width: 560,
      actions: [
        OutlinedButton(
          key: const Key('declaredClose'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.networthDeclaredClose),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bannerError != null) ...[
            InlineBanner(
              key: const Key('declaredError'),
              message: _bannerError!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: LabeledField(
                    label: l10n.networthDeclaredMonth,
                    errorText: _monthError,
                    child: TextFormField(
                      key: const Key('declaredMonth'),
                      controller: _monthController,
                      focusNode: _monthFocus,
                      autofocus: true,
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
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: LabeledField(
                    label: l10n.networthDeclaredAmount,
                    child: MoneyField(
                      key: const Key('declaredAmount'),
                      controller: _amountController,
                      currency: widget.currency,
                      // An overdrawn total is a total too.
                      allowNegative: true,
                      validator: (value) =>
                          parseMoneyMinor(
                                value ?? '',
                                locale,
                                allowNegative: true,
                              ) ==
                              null
                          ? l10n.networthDeclaredAmountInvalid
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Padding(
                  // Level with the fields, under their labels.
                  padding: const EdgeInsets.only(top: 22),
                  child: PrimaryButton(
                    key: const Key('declaredSave'),
                    label: l10n.networthDeclaredSave,
                    height: 44,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            // The list stays on screen while a write re-reads it.
            child: entries.when(
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      key: const Key('declaredList'),
                      shrinkWrap: true,
                      children: [
                        for (final entry in value.reversed)
                          _DeclaredRow(
                            entry: entry,
                            locale: locale,
                            onEdit: () => _edit(entry),
                            onDelete: () => _remove(entry.month),
                          ),
                      ],
                    ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      l10n.networthDeclaredLoadFailed,
                      key: const Key('declaredLoadFailed'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      key: const Key('declaredRetry'),
                      onPressed: () =>
                          ref.invalidate(declaredBalancesControllerProvider),
                      child: Text(l10n.networthDeclaredRetry),
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One declared month: « mars 2025 », the chip when imports cover it, the
/// neutral total, then edit and delete.
class _DeclaredRow extends StatelessWidget {
  const _DeclaredRow({
    required this.entry,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });

  final DeclaredBalance entry;
  final String locale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final key = formatMonthInput(entry.month);

    return Container(
      key: Key('declaredRow-$key'),
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  DateFormat.yMMMM(locale).format(entry.month),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (entry.superseded) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: AppChip(
                      key: Key('declaredSuperseded-$key'),
                      label: l10n.networthDeclaredSuperseded,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AmountText(
            amountMinor: entry.amountMinor,
            currency: entry.currency,
            colorize: false,
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            key: Key('declaredEdit-$key'),
            onPressed: onEdit,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.networthDeclaredEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          IconButton(
            key: Key('declaredDelete-$key'),
            onPressed: onDelete,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.networthDeclaredDelete,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
