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

/// Opens the edit modal for [series]. Resolves to the saved series, or `null`
/// when the user cancelled.
Future<RecurringSeries?> showSeriesForm(
  BuildContext context, {
  required RecurringSeries series,
}) {
  return showDialog<RecurringSeries>(
    context: context,
    builder: (_) => SeriesFormModal(initial: series),
  );
}

/// The 480 px « Modifier le paiement récurrent » modal behind the kebab's
/// « Modifier » (`docs/design/10` frame ④).
///
/// Edit only. A series is never created from scratch: it starts from its
/// charges, in « Marquer comme récurrent », so detection can keep it up to
/// date. Here the user can set a cadence detection never concludes, such as
/// `Irrégulier`.
class SeriesFormModal extends ConsumerStatefulWidget {
  const SeriesFormModal({super.key, required this.initial});

  final RecurringSeries initial;

  @override
  ConsumerState<SeriesFormModal> createState() => _SeriesFormModalState();
}

class _SeriesFormModalState extends ConsumerState<SeriesFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial.label,
  );
  final _amountController = TextEditingController();

  /// Guards the one-time locale-aware fill of [_amountController]. Done in
  /// [didChangeDependencies] because it must round-trip through the same
  /// [NumberFormat] `_parseMinorUnits` re-parses on submit, and that needs the
  /// active locale — unavailable before the widget is mounted.
  bool _amountFilled = false;

  late Cadence _cadence = widget.initial.cadence;
  late String? _categoryId = widget.initial.categoryId;

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountFilled) return;
    final amountMinor = widget.initial.expectedAmountMinor;
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locale = Localizations.localeOf(context).toString();
    final magnitude = _parseMinorUnits(_amountController.text, locale);
    if (magnitude == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final controller = ref.read(subscriptionsControllerProvider.notifier);
    try {
      // Stored negative: a subscription is an outflow, and the ledger's sign
      // convention is not something a form may opt out of.
      final saved = await controller.updateSeries(
        widget.initial.id,
        label: _labelController.text.trim(),
        categoryId: _categoryId,
        cadence: _cadence,
        expectedAmountMinor: -magnitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizeRecurringError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.watch(subscriptionAccountsProvider).value ?? const [];
    final categories =
        ref.watch(subscriptionCategoriesProvider).value ?? const [];
    final accountName = accounts
        .where((account) => account.id == widget.initial.accountId)
        .firstOrNull
        ?.displayName;

    return AppModal(
      title: l10n.subscriptionFormEditTitle,
      width: 480,
      actions: [
        OutlinedButton(
          key: const Key('seriesFormCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.subscriptionFormCancel),
        ),
        PrimaryButton(
          key: const Key('seriesFormSubmit'),
          label: l10n.subscriptionFormSave,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              InlineBanner(
                key: const Key('seriesFormError'),
                message: _errorText!,
              ),
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
                    // The account is fixed once the series exists: the API has
                    // no way to move one, and offering a control that silently
                    // does nothing is worse than not offering it.
                    child: ReadOnlyField(value: accountName ?? ''),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final locale = Localizations.localeOf(
                          context,
                        ).toString();
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
