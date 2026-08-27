import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../application/subscriptions_controller.dart';
import '../domain/recurring_series.dart';
import 'recurring_error_localizer.dart';
import 'recurring_labels.dart';

/// Opens the create/edit subscription modal. Resolves to the saved series, or
/// `null` when the user cancelled.
Future<RecurringSeries?> showSeriesForm(
  BuildContext context, {
  RecurringSeries? initial,
}) {
  return showDialog<RecurringSeries>(
    context: context,
    builder: (_) => SeriesFormModal(initial: initial),
  );
}

/// The 480 px « Nouvel abonnement » modal (`docs/design/10` frame ④), reused
/// for the kebab's « Modifier ».
///
/// This is the only place `Irrégulier` can be chosen. Detection concludes a
/// cadence or concludes nothing (`PROJECT.md` §12), so an irregular series only
/// ever exists because a user said so here.
class SeriesFormModal extends ConsumerStatefulWidget {
  const SeriesFormModal({super.key, this.initial});

  final RecurringSeries? initial;

  @override
  ConsumerState<SeriesFormModal> createState() => _SeriesFormModalState();
}

class _SeriesFormModalState extends ConsumerState<SeriesFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(text: widget.initial?.label);
  final _amountController = TextEditingController();

  /// Guards the one-time locale-aware fill of [_amountController]. Done in
  /// [didChangeDependencies] because it must round-trip through the same
  /// [NumberFormat] `_parseMinorUnits` re-parses on submit, and that needs the
  /// active locale — unavailable before the widget is mounted.
  bool _amountFilled = false;

  late Cadence _cadence = widget.initial?.cadence ?? Cadence.monthly;
  late String? _accountId = widget.initial?.accountId;
  late String? _categoryId = widget.initial?.categoryId;

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountFilled) return;
    final amountMinor = widget.initial?.expectedAmountMinor;
    if (amountMinor == null) return;
    final locale = Localizations.localeOf(context).toString();
    // Shown unsigned: the field asks what the subscription costs, and the sign
    // is this form's own statement that a subscription is an outflow.
    _amountController.text = NumberFormat.decimalPattern(
      locale,
    ).format(amountMinor.abs() / 100);
    _amountFilled = true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int? _parseMinorUnits(String text, String locale) {
    try {
      final value = NumberFormat.decimalPattern(locale).parse(text.trim());
      final minor = (value.toDouble() * 100).round();
      return minor > 0 ? minor : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _submit(List<SeriesAccount> accounts) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final magnitude = _parseMinorUnits(_amountController.text, locale);
    final accountId = _accountId ?? accounts.firstOrNull?.id;
    if (magnitude == null || accountId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final controller = ref.read(subscriptionsControllerProvider.notifier);
    try {
      // Stored negative: a subscription is an outflow, and the ledger's sign
      // convention is not something a form may opt out of (`PROJECT.md` §8).
      final saved = _isEditing
          ? await controller.updateSeries(
              widget.initial!.id,
              label: _labelController.text.trim(),
              categoryId: _categoryId,
              cadence: _cadence,
              expectedAmountMinor: -magnitude,
            )
          : await controller.create(
              label: _labelController.text.trim(),
              accountId: accountId,
              expectedAmountMinor: -magnitude,
              cadence: _cadence,
              categoryId: _categoryId,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeRecurringError(AppLocalizations.of(context)!, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(subscriptionAccountsProvider).value ?? const [];
    final categories = ref.watch(subscriptionCategoriesProvider).value ?? const [];
    final selectedAccount = _accountId ?? accounts.firstOrNull?.id;

    return AppModal(
      title: _isEditing ? l10n.subscriptionFormEditTitle : l10n.subscriptionFormCreateTitle,
      width: 480,
      actions: [
        OutlinedButton(
          key: const Key('seriesFormCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.subscriptionFormCancel),
        ),
        PrimaryButton(
          key: const Key('seriesFormSubmit'),
          label: _isEditing ? l10n.subscriptionFormSave : l10n.subscriptionFormSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting || accounts.isEmpty
              ? null
              : () => _submit(accounts),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.subscriptionFormIntro,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorText != null) ...[
              InlineBanner(key: const Key('seriesFormError'), message: _errorText!),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledField(
              label: l10n.subscriptionFormNameLabel,
              child: TextFormField(
                key: const Key('seriesFormName'),
                controller: _labelController,
                autofocus: true,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.subscriptionFormNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.subscriptionFormAccountLabel,
                    child: accounts.isEmpty
                        ? ReadOnlyField(value: l10n.subscriptionFormNoAccounts)
                        // The account is fixed once the series exists: the API
                        // has no way to move one, and offering a control that
                        // silently does nothing is worse than not offering it.
                        : _isEditing
                        ? ReadOnlyField(
                            value: accounts
                                    .where((a) => a.id == selectedAccount)
                                    .firstOrNull
                                    ?.displayName ??
                                '',
                          )
                        : AppSelect<String>(
                            key: const Key('seriesFormAccount'),
                            value: selectedAccount ?? accounts.first.id,
                            onChanged: (value) => setState(() => _accountId = value),
                            items: [
                              for (final account in accounts)
                                AppSelectItem(
                                  value: account.id,
                                  label: account.displayName,
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                SizedBox(
                  width: 130,
                  child: LabeledField(
                    label: l10n.subscriptionFormAmountLabel,
                    child: TextFormField(
                      key: const Key('seriesFormAmount'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final locale = Localizations.localeOf(context).toString();
                        return _parseMinorUnits(value ?? '', locale) == null
                            ? l10n.subscriptionFormAmountInvalid
                            : null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.subscriptionFormCadenceLabel,
                    helper: l10n.subscriptionFormCadenceHelp,
                    child: AppSelect<Cadence>(
                      key: const Key('seriesFormCadence'),
                      value: _cadence,
                      onChanged: (value) => setState(() => _cadence = value),
                      items: [
                        for (final cadence in Cadence.values)
                          AppSelectItem(
                            value: cadence,
                            label: cadenceLabel(l10n, cadence),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: LabeledField(
                    label: l10n.subscriptionFormCategoryLabel,
                    child: AppSelect<String?>(
                      key: const Key('seriesFormCategory'),
                      value: _categoryId,
                      onChanged: (value) => setState(() => _categoryId = value),
                      items: [
                        AppSelectItem(
                          value: null,
                          label: l10n.subscriptionFormCategoryNone,
                        ),
                        for (final category in categories)
                          AppSelectItem(
                            value: category.id,
                            label: localizedCategoryName(l10n, category.name),
                            leading: _Swatch(category: category),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The 10 px hue square beside a category in the picker — the spec's swatch.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    final hue = CategoryHues.forSlug(
      categorySlugFor(name: category.name, kind: category.kind),
    );
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: hue,
        borderRadius: BorderRadius.circular(AppRadii.xs - 1),
      ),
    );
  }
}
