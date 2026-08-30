import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';

/// Opens the filter bar's date range modal.
///
/// Resolves to the chosen bounds, or `null` when the user cancelled — a pair of
/// nulls is a cleared range, which is why the result is a record rather than a
/// nullable [DateTimeRange].
Future<(DateTime?, DateTime?)?> showTransactionDateRange(
  BuildContext context, {
  DateTime? from,
  DateTime? to,
}) {
  return showDialog<(DateTime?, DateTime?)>(
    context: context,
    builder: (_) => DateRangeModal(from: from, to: to),
  );
}

/// The « Période » modal: two [DateField]s, so the range is typed or picked
/// from the very calendar the goal and allocation forms open.
///
/// Material's own [showDateRangePicker] is a full-screen surface with its own
/// header and typography, none of which the app's theme reaches — a second
/// calendar the user would have to learn. Two fields keep one calendar in the
/// app, and let someone who knows the dates type them without opening it at all.
class DateRangeModal extends StatefulWidget {
  const DateRangeModal({super.key, this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  State<DateRangeModal> createState() => _DateRangeModalState();
}

class _DateRangeModalState extends State<DateRangeModal> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  /// Guards the one-time fill of both fields: they round-trip through the same
  /// locale-aware formatter that re-reads them on submit, and the locale is
  /// only available once the widget is mounted.
  bool _filled = false;

  /// The calendar's bounds — the same decade back and year forward the filter
  /// has always offered, since a range is asked of history, not of the future.
  static final _now = DateTime.now();
  static final _firstDate = DateTime(_now.year - 10);
  static final _lastDate = DateTime(_now.year + 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final locale = Localizations.localeOf(context).toString();
    final format = appDateFormat(locale);
    if (widget.from case final date?) _fromController.text = format.format(date);
    if (widget.to case final date?) _toController.text = format.format(date);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// Validates one bound against the other: a filled field has to be a date the
  /// locale can read, an empty one is only allowed when its partner is empty
  /// too, and the pair has to run forwards.
  String? _validate(String? raw, {required bool isFrom}) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final text = (raw ?? '').trim();
    final otherText = (isFrom ? _toController.text : _fromController.text).trim();

    if (text.isEmpty) {
      return otherText.isEmpty ? null : l10n.transactionsDateRangeIncomplete;
    }

    final date = parseDateInput(text, locale);
    if (date == null) return l10n.transactionsDateRangeInvalid;

    // Only the end field reports the ordering, so a reversed range underlines
    // one date rather than both.
    if (isFrom) return null;
    final start = parseDateInput(otherText, locale);
    if (start != null && date.isBefore(start)) return l10n.transactionsDateRangeOrder;
    return null;
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    Navigator.of(context).pop((
      parseDateInput(_fromController.text, locale),
      parseDateInput(_toController.text, locale),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppModal(
      title: l10n.transactionsDateRangeTitle,
      width: 420,
      actions: [
        OutlinedButton(
          key: const Key('transactionsDateRangeCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.transactionsDateRangeCancel),
        ),
        PrimaryButton(
          key: const Key('transactionsDateRangeApply'),
          label: l10n.transactionsDateRangeApply,
          onPressed: _apply,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.transactionsDateRangeFromLabel,
                    child: DateField(
                      key: const Key('transactionsDateRangeFrom'),
                      controller: _fromController,
                      firstDate: _firstDate,
                      lastDate: _lastDate,
                      calendarTooltip: l10n.transactionsDateRangePickFrom,
                      validator: (value) => _validate(value, isFrom: true),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: LabeledField(
                    label: l10n.transactionsDateRangeToLabel,
                    child: DateField(
                      key: const Key('transactionsDateRangeTo'),
                      controller: _toController,
                      firstDate: _firstDate,
                      lastDate: _lastDate,
                      calendarTooltip: l10n.transactionsDateRangePickTo,
                      validator: (value) => _validate(value, isFrom: false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Clearing both fields is how the filter is lifted, so the modal
            // says so rather than leaving the user hunting for a reset.
            Text(l10n.transactionsDateRangeHelp, style: AppTextStyles.helper),
          ],
        ),
      ),
    );
  }
}
