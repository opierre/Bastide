import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/monogram_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';

/// Opens the create/edit account modal.
void showAccountForm(BuildContext context, {Account? initial}) {
  showDialog<void>(context: context, builder: (_) => AccountForm(initial: initial));
}

/// Create/edit modal. Opening balance is only editable at creation — the
/// backend treats it as the seed for the derived balance cache and doesn't
/// accept it on `PATCH` (see `AccountUpdate`), so edit mode shows it
/// read-only, alongside currency (never editable in Phase 1 — one currency
/// per user, see the multi-currency skill).
class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key, this.initial});

  final Account? initial;

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial?.name);
  late final _institutionController = TextEditingController(
    text: widget.initial?.institution,
  );
  late final _openingBalanceController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.openingBalanceMinor / 100).toStringAsFixed(2),
  );
  late AccountType _type = widget.initial?.type ?? AccountType.checking;

  /// Mirrors the institution field so the logo preview updates as it is typed.
  late String _institution = widget.initial?.institution ?? '';

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      if (_isEditing) {
        await ref
            .read(accountsControllerProvider.notifier)
            .updateAccount(
              widget.initial!.id,
              name: _nameController.text.trim(),
              type: _type,
              institution: _institutionController.text.trim(),
            );
      } else {
        final locale = Localizations.localeOf(context).toString();
        final openingBalanceMinor = _parseMinorUnits(
          _openingBalanceController.text,
          locale,
        );
        await ref
            .read(accountsControllerProvider.notifier)
            .create(
              name: _nameController.text.trim(),
              type: _type,
              institution: _institutionController.text.trim(),
              openingBalanceMinor: openingBalanceMinor,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = localizeAccountError(l10n, error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int _parseMinorUnits(String text, String locale) {
    final value = NumberFormat.decimalPattern(locale).parse(text.trim());
    return (value.toDouble() * 100).round();
  }

  String? _validateOpeningBalance(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) return l10n.accountOpeningBalanceRequired;
    try {
      NumberFormat.decimalPattern(
        Localizations.localeOf(context).toString(),
      ).parse(value.trim());
      return null;
    } on FormatException {
      return l10n.accountOpeningBalanceInvalid;
    }
  }

  String _typeLabel(AppLocalizations l10n, AccountType type) => switch (type) {
    AccountType.checking => l10n.accountTypeChecking,
    AccountType.savings => l10n.accountTypeSavings,
    AccountType.credit => l10n.accountTypeCredit,
    AccountType.cash => l10n.accountTypeCash,
    AccountType.other => l10n.accountTypeOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency =
        widget.initial?.currency ?? ref.watch(currentUserProvider)?.currency ?? '';

    return AppModal(
      width: 480,
      title: _isEditing ? l10n.accountFormEditTitle : l10n.accountFormCreateTitle,
      actions: [
        TextButton(
          key: const Key('accountFormCancelButton'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.accountFormCancel),
        ),
        PrimaryButton(
          key: const Key('accountFormSubmitButton'),
          label: _isEditing ? l10n.accountFormSubmitEdit : l10n.accountFormSubmitCreate,
          isLoading: _isSubmitting,
          height: 42,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: l10n.accountNameLabel,
              child: TextFormField(
                key: const Key('accountNameField'),
                controller: _nameController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.accountNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.accountTypeLabel,
              child: DropdownButtonFormField<AccountType>(
                key: const Key('accountTypeField'),
                initialValue: _type,
                borderRadius: BorderRadius.circular(AppRadii.md),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem(value: type, child: Text(_typeLabel(l10n, type))),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.accountOpeningBalanceLabel,
              child: TextFormField(
                key: const Key('accountOpeningBalanceField'),
                controller: _openingBalanceController,
                enabled: !_isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                // A form value is a neutral figure, not a movement, so it keeps
                // the primary text color rather than taking a sign color.
                style: tabularNumberStyle(Theme.of(context).textTheme.bodyLarge!),
                validator: _isEditing
                    ? null
                    : (value) => _validateOpeningBalance(value, l10n),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.accountInstitutionLabel,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('accountInstitutionField'),
                      controller: _institutionController,
                      onChanged: (value) => setState(() => _institution = value),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? l10n.accountInstitutionRequired
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  _LogoPreview(institution: _institution),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.accountCurrencyLabel,
              helper: l10n.accountCurrencyNote,
              child: ReadOnlyField(
                key: const Key('accountCurrencyField'),
                value: currency,
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AppSpacing.md),
              InlineBanner(
                key: const Key('accountFormErrorText'),
                message: _errorText!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live monogram for whatever institution name is typed, plus a confirmation
/// once the name is one we have a pinned color for.
///
/// The preview is what makes the monogram read as deliberate rather than as a
/// missing logo: the user sees the chip they will get before saving.
class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.institution});

  final String institution;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recognized =
        institution.trim().isNotEmpty && MonogramAvatar.hueFor(institution) != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InstitutionAvatar(name: institution, size: 40),
        if (recognized) ...[
          const SizedBox(width: AppSpacing.sm - 2),
          const Icon(Icons.check_rounded, size: 13, color: AppColors.positive),
          const SizedBox(width: 2),
          Text(
            l10n.accountLogoRecognized,
            key: const Key('accountLogoRecognized'),
            style: AppTextStyles.helper.copyWith(color: AppColors.positive),
          ),
        ],
      ],
    );
  }
}
