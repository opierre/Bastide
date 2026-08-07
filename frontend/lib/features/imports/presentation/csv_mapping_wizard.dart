import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/imports_controller.dart';
import '../domain/csv_template.dart';
import '../domain/import_batch.dart';
import 'import_error_localizer.dart';

/// Opens the one-time CSV column-mapping wizard and resolves to the resulting
/// batch, or `null` if the user backed out.
Future<ImportBatch?> showCsvMappingWizard(
  BuildContext context, {
  required String accountId,
  required String institution,
  required PickedImportFile file,
  required String currency,
}) {
  return showDialog<ImportBatch>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CsvMappingWizard(
      accountId: accountId,
      institution: institution,
      file: file,
      currency: currency,
    ),
  );
}

/// Two-step wizard: the file's format, then its columns with a live preview.
///
/// The preview is the point of the whole screen — it parses a sample through
/// the *backend's* CSV parser, so what the user confirms is exactly what the
/// import will read, and a wrong column is caught before anything is written.
///
/// The mapping is saved as a `csv_template` on confirm, always: the import
/// endpoint identifies a CSV by its template id, so there is no "import this
/// once without saving" path. That is why the wizard only runs the first time
/// for a given bank — afterwards the panel reuses the saved template.
class CsvMappingWizard extends ConsumerStatefulWidget {
  const CsvMappingWizard({
    super.key,
    required this.accountId,
    required this.institution,
    required this.file,
    required this.currency,
  });

  final String accountId;

  /// The account's institution, which seeds the bank name the template is
  /// remembered under.
  final String institution;

  final PickedImportFile file;
  final String currency;

  @override
  ConsumerState<CsvMappingWizard> createState() => _CsvMappingWizardState();
}

class _CsvMappingWizardState extends ConsumerState<CsvMappingWizard> {
  static const _previewDebounce = Duration(milliseconds: 350);

  late CsvTemplateDraft _draft = CsvTemplateDraft(bankName: widget.institution);
  late final _bankNameController = TextEditingController(text: widget.institution);

  int _step = 0;
  bool _isSubmitting = false;
  String? _submitError;

  /// `null` until the first preview is requested. The confirm action stays
  /// disabled until this holds rows — a mapping that can't produce a preview
  /// can't produce an import either.
  AsyncValue<List<CsvPreviewRow>>? _preview;

  Timer? _previewDebounceTimer;

  /// Guards against an older in-flight preview overwriting a newer one when
  /// the user keeps editing while a request is out.
  int _previewRequestId = 0;

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _bankNameController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      !_isSubmitting &&
      _draft.bankName.trim().isNotEmpty &&
      _preview?.hasValue == true &&
      _preview!.value!.isNotEmpty;

  void _update(CsvTemplateDraft draft) {
    setState(() => _draft = draft);
    if (_step == 1) _schedulePreview();
  }

  void _schedulePreview() {
    _previewDebounceTimer?.cancel();
    if (!_draft.isMappingComplete) {
      setState(() => _preview = null);
      return;
    }
    _previewDebounceTimer = Timer(_previewDebounce, _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    final requestId = ++_previewRequestId;
    setState(() => _preview = const AsyncValue.loading());

    final result = await AsyncValue.guard(
      () => ref
          .read(importsControllerProvider.notifier)
          .previewCsv(draft: _draft, file: widget.file),
    );

    if (!mounted || requestId != _previewRequestId) return;
    setState(() => _preview = result);
  }

  void _goToColumns() {
    setState(() => _step = 1);
    _schedulePreview();
  }

  /// Saves the mapping, then imports the file with it. The template is created
  /// first because the import endpoint needs its id to parse the file as CSV.
  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final template = await ref
          .read(csvTemplatesControllerProvider.notifier)
          .create(_draft);
      final batch = await ref
          .read(importsControllerProvider.notifier)
          .importFile(
            accountId: widget.accountId,
            file: widget.file,
            csvTemplateId: template.id,
          );
      if (mounted) Navigator.of(context).pop(batch);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = localizeImportError(l10n, error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      width: 780,
      title: l10n.csvWizardTitle,
      actions: [
        TextButton(
          key: const Key('csvWizardCancelButton'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.csvWizardCancel),
        ),
        if (_step == 0)
          PrimaryButton(
            key: const Key('csvWizardNextButton'),
            label: l10n.csvWizardNext,
            height: 42,
            onPressed: _draft.bankName.trim().isEmpty ? null : _goToColumns,
          )
        else
          PrimaryButton(
            key: const Key('csvWizardConfirmButton'),
            label: l10n.csvWizardConfirm,
            loadingLabel: l10n.csvWizardConfirming,
            isLoading: _isSubmitting,
            height: 42,
            onPressed: _canConfirm ? _confirm : null,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stepper(step: _step),
          const SizedBox(height: AppSpacing.lg),
          if (_step == 0) _formatStep(l10n) else _columnsStep(l10n),
          if (_submitError != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: const Key('csvWizardSubmitError'),
              message: _submitError!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: l10n.csvWizardBankLabel,
          helper: l10n.csvWizardBankHelper,
          child: TextFormField(
            key: const Key('csvWizardBankField'),
            controller: _bankNameController,
            onChanged: (value) => _update(_draft.copyWith(bankName: value)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 3×2 control grid: the six format decisions a French bank export
        // needs, all visible at once rather than paged.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: l10n.csvWizardDelimiterLabel,
                child: _Dropdown<String>(
                  fieldKey: const Key('csvWizardDelimiterField'),
                  value: _draft.delimiter,
                  options: {
                    ';': l10n.csvDelimiterSemicolon,
                    ',': l10n.csvDelimiterComma,
                    '\t': l10n.csvDelimiterTab,
                    '|': l10n.csvDelimiterPipe,
                  },
                  onChanged: (value) => _update(_draft.copyWith(delimiter: value)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: l10n.csvWizardEncodingLabel,
                child: _Dropdown<String>(
                  fieldKey: const Key('csvWizardEncodingField'),
                  value: _draft.encoding,
                  // Encoding identifiers are technical names, not UI prose, so
                  // they render as-is in both locales.
                  options: const {
                    'latin-1': 'Latin-1 (ISO-8859-1)',
                    'utf-8': 'UTF-8',
                    'utf-8-sig': 'UTF-8 (BOM)',
                    'cp1252': 'Windows-1252',
                  },
                  onChanged: (value) => _update(_draft.copyWith(encoding: value)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: l10n.csvWizardDateFormatLabel,
                child: _Dropdown<String>(
                  fieldKey: const Key('csvWizardDateFormatField'),
                  value: _draft.dateFormat,
                  // Shown as the pattern the user recognizes from their file;
                  // the strptime form the backend parses with is the key.
                  options: const {
                    '%d/%m/%Y': 'dd/MM/yyyy',
                    '%d/%m/%y': 'dd/MM/yy',
                    '%Y-%m-%d': 'yyyy-MM-dd',
                    '%d.%m.%Y': 'dd.MM.yyyy',
                    '%d-%m-%Y': 'dd-MM-yyyy',
                  },
                  onChanged: (value) => _update(_draft.copyWith(dateFormat: value)),
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
                label: l10n.csvWizardDecimalLabel,
                child: AppSegmented<String>(
                  key: const Key('csvWizardDecimalField'),
                  value: _draft.decimalSeparator,
                  segments: [
                    AppSegment(value: ',', label: l10n.csvDecimalComma),
                    AppSegment(value: '.', label: l10n.csvDecimalPeriod),
                  ],
                  onChanged: (value) =>
                      _update(_draft.copyWith(decimalSeparator: value)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: l10n.csvWizardAmountsLabel,
                child: AppSegmented<AmountStrategy>(
                  key: const Key('csvWizardAmountsField'),
                  value: _draft.amountStrategy,
                  segments: [
                    AppSegment(
                      value: AmountStrategy.signed,
                      label: l10n.csvAmountStrategySigned,
                    ),
                    AppSegment(
                      value: AmountStrategy.debitCredit,
                      label: l10n.csvAmountStrategyDebitCredit,
                    ),
                  ],
                  // Switching strategy leaves the columns of the other layout
                  // in the map; they are simply ignored, and keeping them means
                  // toggling back doesn't lose what was already typed.
                  onChanged: (value) =>
                      _update(_draft.copyWith(amountStrategy: value)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: l10n.csvWizardHeaderOffsetLabel,
                helper: l10n.csvWizardHeaderOffsetHelper,
                child: TextFormField(
                  key: const Key('csvWizardHeaderOffsetField'),
                  initialValue: '${_draft.headerOffset}',
                  keyboardType: TextInputType.number,
                  style: tabularNumberStyle(
                    Theme.of(context).textTheme.bodyLarge!,
                  ),
                  onChanged: (value) => _update(
                    _draft.copyWith(headerOffset: int.tryParse(value.trim()) ?? 0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _columnsStep(AppLocalizations l10n) {
    final fields = [
      (CsvField.bookedDate, l10n.csvColumnBookedDate, true),
      (CsvField.description, l10n.csvColumnDescription, true),
      if (_draft.amountStrategy == AmountStrategy.signed)
        (CsvField.amount, l10n.csvColumnAmount, true)
      else ...[
        (CsvField.debit, l10n.csvColumnDebit, true),
        (CsvField.credit, l10n.csvColumnCredit, true),
      ],
      (CsvField.valueDate, l10n.csvColumnValueDate, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.csvWizardColumnsHint, style: AppTextStyles.helper),
        const SizedBox(height: AppSpacing.md),
        for (final (field, label, required) in fields) ...[
          _MappingRow(
            field: field,
            label: label,
            required: required,
            value: _draft.columnMap[field] ?? '',
            onChanged: (column) => _update(_draft.withColumn(field, column)),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.csvWizardPreviewTitle.toUpperCase(), style: AppTextStyles.sectionLabel),
        const SizedBox(height: AppSpacing.sm + 2),
        _PreviewPane(preview: _preview, currency: widget.currency),
      ],
    );
  }
}

/// The two-step progress line at the top of the modal.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _StepChip(index: 1, label: l10n.csvWizardStepFormat, done: step > 0, active: step == 0),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        const Expanded(child: Divider(color: AppColors.borderSubtle)),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        _StepChip(index: 2, label: l10n.csvWizardStepColumns, done: false, active: step == 1),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlighted = done || active;
    final color = highlighted ? AppColors.iris : AppColors.textDisabled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? AppColors.irisSoft : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 13, color: AppColors.iris)
              : Text(
                  '$index',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// One canonical field paired with the CSV column that feeds it.
class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.field,
    required this.label,
    required this.required,
    required this.value,
    required this.onChanged,
  });

  final String field;
  final String label;
  final bool required;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(AppRadii.inset),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              key: Key('csvWizardColumn-$field'),
              initialValue: value,
              decoration: InputDecoration(hintText: l10n.csvWizardColumnHint),
              onChanged: onChanged,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.iris),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (!required) ...[
                  const SizedBox(width: AppSpacing.sm - 2),
                  Text(l10n.csvWizardColumnOptional, style: AppTextStyles.helper),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The live preview: the sample rows the backend parsed with the current
/// mapping, or the reason it couldn't.
class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.preview, required this.currency});

  final AsyncValue<List<CsvPreviewRow>>? preview;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (preview) {
      null => _Placeholder(message: l10n.csvWizardPreviewPending),
      AsyncLoading() => const Padding(
        key: Key('csvWizardPreviewLoading'),
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SkeletonList(itemCount: 3, itemHeight: 34),
      ),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineBanner(
            key: const Key('csvWizardPreviewError'),
            message: localizeImportError(l10n, error),
          ),
          if (importErrorDetail(error) case final detail?) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Text(detail, style: AppTextStyles.mono),
          ],
        ],
      ),
      AsyncData(:final value) when value.isEmpty => _Placeholder(
        message: l10n.csvWizardPreviewEmpty,
      ),
      AsyncData(:final value) => _PreviewTable(rows: value, currency: currency),
    };
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('csvWizardPreviewPlaceholder'),
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.helper,
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.rows, required this.currency});

  final List<CsvPreviewRow> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('csvWizardPreviewTable'),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    l10n.csvPreviewDateHeader.toUpperCase(),
                    style: AppTextStyles.sectionLabel,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.csvPreviewDescriptionHeader.toUpperCase(),
                    style: AppTextStyles.sectionLabel,
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    l10n.csvPreviewAmountHeader.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.sectionLabel,
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) ...[
            const Divider(color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      dateFormat.format(row.bookedDate),
                      style: tabularNumberStyle(textTheme.bodyMedium!),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.descriptionRaw,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        amountMinor: row.amountMinor,
                        currency: currency,
                        showPositiveSign: true,
                        style: textTheme.bodyMedium!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A select over a fixed option set, keyed by the value that goes on the wire
/// and labelled with what the user recognizes.
///
/// The map form is what the call sites want — a wire value paired with its
/// label — so this adapts it to [AppSelect] rather than spelling out an item
/// list at each of the three settings fields.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.fieldKey,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Key fieldKey;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelect<T>(
      key: fieldKey,
      value: value,
      items: [
        for (final entry in options.entries)
          AppSelectItem(value: entry.key, label: entry.value),
      ],
      onChanged: onChanged,
    );
  }
}
