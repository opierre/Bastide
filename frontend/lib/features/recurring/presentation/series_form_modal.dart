import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/category_display.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/category_label.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
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
  return showAppModal<RecurringSeries>(
    context: context,
    builder: (_) => SeriesFormModal(initial: series),
  );
}

/// The 480 px « Modifier le paiement récurrent » modal (`docs/design/10`
/// § Edit modal, `proposal_v6` `m-subscriptions`): Nom · Compte (read-only)
/// · Montant and Cadence side by side · Catégorie, then « Annuler » ·
/// « Enregistrer ».
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

  /// Guards the one-time locale-aware fill of [_amountController]: it needs
  /// the active locale, which is unavailable before the widget is mounted.
  bool _amountFilled = false;

  late Cadence _cadence = widget.initial.cadence;
  late String? _categoryId = widget.initial.categoryId;

  bool _isSubmitting = false;

  /// The user has changed a field: Escape and « Annuler » then ask before
  /// dropping the input, and the scrim no longer closes the modal.
  bool _dirty = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountFilled) return;
    final locale = Localizations.localeOf(context).toString();
    // Shown unsigned: the field asks what the subscription costs, and the sign
    // is this form's own statement that a subscription is an outflow.
    _amountController.text = formatMoneyInput(
      widget.initial.expectedAmountMinor.abs(),
      locale,
    );
    _amountFilled = true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// The typed amount in minor units, or `null` unless it is above zero.
  int? _magnitude(String text) {
    final locale = Localizations.localeOf(context).toString();
    final minor = parseMoneyMinor(text, locale);
    return minor != null && minor > 0 ? minor : null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final magnitude = _magnitude(_amountController.text);
    if (magnitude == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSubmitting = true;
      _saveError = null;
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
      // The input stays as it was; the frame shows the banner.
      setState(() {
        _isSubmitting = false;
        _saveError = localizeRecurringError(l10n, error);
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
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('seriesFormModal'),
      title: l10n.subscriptionFormEditTitle,
      width: AppModalSizes.w480,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _saveError,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('seriesFormCancel')),
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
            LabeledField(
              label: l10n.subscriptionFormNameLabel,
              child: TextFormField(
                key: const Key('seriesFormName'),
                controller: _labelController,
                autofocus: true,
                onChanged: (_) => _touch(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.subscriptionFormNameRequired
                    : null,
              ),
            ),
            gap,
            LabeledField(
              label: l10n.subscriptionFormAccountLabel,
              // The account is fixed once the series exists: the API has no
              // way to move one, and a control that silently does nothing is
              // worse than none.
              child: ReadOnlyField(value: accountName ?? ''),
            ),
            gap,
            ModalFieldRow(
              start: ModalFieldCell(
                label: l10n.subscriptionFormAmountLabel,
                input: MoneyField(
                  key: const Key('seriesFormAmount'),
                  controller: _amountController,
                  currency: widget.initial.currency,
                  onChanged: (_) => _touch(),
                  validator: (value) => _magnitude(value ?? '') == null
                      ? l10n.subscriptionFormAmountInvalid
                      : null,
                ),
              ),
              end: ModalFieldCell(
                label: l10n.subscriptionFormCadenceLabel,
                input: AppSelect<Cadence>(
                  key: const Key('seriesFormCadence'),
                  value: _cadence,
                  onChanged: (value) => setState(() {
                    _cadence = value;
                    _dirty = true;
                  }),
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
            gap,
            LabeledField(
              label: l10n.subscriptionFormCategoryLabel,
              child: AppSelect<String?>(
                key: const Key('seriesFormCategory'),
                value: _categoryId,
                onChanged: (value) => setState(() {
                  _categoryId = value;
                  _dirty = true;
                }),
                items: [
                  AppSelectItem(
                    value: null,
                    label: l10n.subscriptionFormCategoryNone,
                  ),
                  for (final category in categories)
                    AppSelectItem(
                      value: category.id,
                      label: localizedCategoryName(l10n, category.name),
                      leading: _CategoryDot(category: category),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category label's 8 px dot (radius 2) in the category hue, before the
/// name in the select (`00` §7).
class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category});

  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CategoryLabel.dotSize,
      height: CategoryLabel.dotSize,
      decoration: BoxDecoration(
        color: context.categoryColors.forSlug(
          categorySlugFor(name: category.name, kind: category.kind),
        ),
        borderRadius: BorderRadius.circular(AppRadii.bar),
      ),
    );
  }
}
