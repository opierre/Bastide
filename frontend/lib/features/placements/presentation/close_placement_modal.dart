import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/labeled_field.dart';
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

/// « Clôturer » (`17-placements.md` §Modals): the closing date and the
/// final amount received. The placement leaves the net worth from that date
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
    const gap = SizedBox(height: AppSpacing.fieldGap);

    return AppModal(
      key: const Key('closePlacementModal'),
      title: l10n.placementCloseTitle,
      subtitle: Text(l10n.placementCloseLead(widget.investment.name)),
      width: AppSizes.inspector,
      actions: [
        OutlinedButton(
          key: const Key('closePlacementCancel'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.placementFormCancel),
        ),
        PrimaryButton(
          key: const Key('closePlacementSubmit'),
          label: l10n.placementCloseSubmit,
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
                key: const Key('closePlacementError'),
                message: _errorText!,
              ),
              gap,
            ],
            LabeledField(
              label: l10n.placementCloseDate,
              child: DateField(
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
            gap,
            LabeledField(
              label: l10n.placementCloseAmount,
              child: MoneyField(
                key: const Key('closePlacementAmount'),
                controller: _amount,
                currency: widget.investment.currency,
                autofocus: true,
                textAlign: TextAlign.end,
                validator: (value) =>
                    parseMoneyMinor(value ?? '', locale) == null
                    ? l10n.placementCloseAmountInvalid
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
