import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/modal_parts.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/placements_controller.dart';
import '../domain/investment.dart';
import 'placement_form_modal.dart';
import 'placement_labels.dart';

Future<void> showClosePlacementModal(
  BuildContext context, {
  required Investment investment,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => ClosePlacementModal(investment: investment),
  );
}

/// « Clôturer ce placement ? » (`17-placements.md` §Modals, proposal v6
/// `m-investments`): the closing date and the final amount received, side
/// by side. Nothing is lost, so the primary stays ink. The placement leaves the net worth from that date
/// and stays listed, dimmed; a positive amount is recorded as a withdrawal.
class ClosePlacementModal extends ConsumerStatefulWidget {
  const ClosePlacementModal({super.key, required this.investment});

  final Investment investment;

  @override
  ConsumerState<ClosePlacementModal> createState() =>
      _ClosePlacementModalState();
}

class _ClosePlacementModalState extends ConsumerState<ClosePlacementModal> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _amount = TextEditingController();
  bool _filled = false;
  bool _dirty = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final locale = Localizations.localeOf(context).toString();
    _date.text = appDateFormat(locale).format(DateTime.now());
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).toString();
    final date = parsePastDate(_date.text, locale);
    final amount = parseMoneyMinor(_amount.text, locale);
    if (date == null || amount == null) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(placementsControllerProvider.notifier)
          .close(
            widget.investment.id,
            closedOn: date,
            finalAmountMinor: amount,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = localizePlacementError(
          AppLocalizations.of(context)!,
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    return AppModal(
      key: const Key('closePlacementModal'),
      title: l10n.placementCloseTitle,
      subtitle: Text(l10n.placementCloseLead),
      width: AppSizes.inspector,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('closePlacementCancel')),
        PrimaryButton(
          key: const Key('closePlacementSubmit'),
          label: l10n.placementCloseSubmit,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: ModalFieldRow(
          start: ModalFieldCell(
            label: l10n.placementCloseDate,
            input: DateField(
              key: const Key('closePlacementDate'),
              controller: _date,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
              calendarTooltip: l10n.placementFormDatePick,
              validator: (value) => parsePastDate(value ?? '', locale) == null
                  ? l10n.placementFormDateInvalid
                  : null,
            ),
          ),
          end: ModalFieldCell(
            label: l10n.placementCloseAmount,
            input: MoneyField(
              key: const Key('closePlacementAmount'),
              controller: _amount,
              currency: widget.investment.currency,
              textAlign: TextAlign.end,
              validator: (value) => parseMoneyMinor(value ?? '', locale) == null
                  ? l10n.placementCloseAmountInvalid
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
