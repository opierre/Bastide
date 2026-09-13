import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';
import 'account_type_label.dart';

/// Opens the create/edit account modal.
///
/// Resolves to the account that was created, or `null` when the user cancelled
/// or was editing — so a caller that opened the form to fill a gap (the imports
/// panel, needing an account for the statement it holds) can carry on with it.
Future<Account?> showAccountForm(
  BuildContext context, {
  Account? initial,
  AccountPrefill? prefill,
}) {
  return showDialog<Account>(
    context: context,
    builder: (_) => AccountForm(initial: initial, prefill: prefill),
  );
}

/// Create/edit modal. The balance field means something different at each end
/// of the account's life (see [_AccountFormState]) but is editable at both —
/// on `PATCH` it is a manual correction, shifting the cached balance and every
/// saved snapshot by the delta rather than being treated as a fresh figure
/// (see the backend's `shift_opening_balance`). Currency is never editable and
/// is not a field of its own — it rides as the balance's suffix, taken from the
/// account, else from the statement's `CURDEF`, else from the profile (one
/// currency per user in Phase 1 — see the multi-currency skill).
///
/// [prefill] seeds the create form from something the user didn't type — today,
/// the account block of an OFX statement. Fields the statement *proposes* stay
/// editable (the name it suggests is our own construction); fields it *declares*
/// — its closing balance, the bank it names — are shown read-only, because they
/// are the file's answer and retyping them can only introduce a discrepancy.
class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key, this.initial, this.prefill});

  final Account? initial;
  final AccountPrefill? prefill;

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? widget.prefill?.name,
  );
  late final _institutionController = TextEditingController(
    text: widget.initial?.institution ?? widget.prefill?.institution,
  );
  final _openingBalanceController = TextEditingController();

  /// Guards the one-time locale-aware fill of [_openingBalanceController] —
  /// with the account's own figure when editing, with the balance the statement
  /// declares when creating from one. Done in [didChangeDependencies] rather
  /// than at field-init time because it must match the same [NumberFormat]
  /// `_parseMinorUnits` re-parses on submit, which needs `context` for the
  /// active locale — unavailable before the widget is mounted.
  bool _openingBalanceFilled = false;

  late AccountType _type =
      widget.initial?.type ?? widget.prefill?.type ?? AccountType.checking;

  /// Mirrors the institution field so the logo preview updates as it is typed.
  late String _institution =
      widget.initial?.institution ?? widget.prefill?.institution ?? '';

  bool _isSubmitting = false;
  String? _errorText;

  bool get _isEditing => widget.initial != null;

  /// The statement declared a closing balance, so the balance field states it
  /// rather than asking for it.
  bool get _balanceFromStatement =>
      !_isEditing && widget.prefill?.balanceMinor != null;

  /// The statement named its bank, so the institution field states it too.
  bool get _institutionFromStatement =>
      !_isEditing && (widget.prefill?.institution?.trim().isNotEmpty ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openingBalanceFilled) return;
    final balanceMinor =
        widget.initial?.openingBalanceMinor ?? widget.prefill?.balanceMinor;
    if (balanceMinor == null) return;
    final locale = Localizations.localeOf(context).toString();
    _openingBalanceController.text = NumberFormat.decimalPattern(
      locale,
    ).format(balanceMinor / 100);
    _openingBalanceFilled = true;
  }

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
      final locale = Localizations.localeOf(context).toString();
      // A statement-declared balance goes back out exactly as it came in: it was
      // never typed, so there is nothing to re-parse and no rounding to risk.
      final openingBalanceMinor = _balanceFromStatement
          ? widget.prefill!.balanceMinor!
          : _parseMinorUnits(_openingBalanceController.text, locale);

      Account? created;
      if (_isEditing) {
        await ref
            .read(accountsControllerProvider.notifier)
            .updateAccount(
              widget.initial!.id,
              name: _nameController.text.trim(),
              type: _type,
              institution: _institutionController.text.trim(),
              openingBalanceMinor: openingBalanceMinor,
            );
      } else {
        created = await ref
            .read(accountsControllerProvider.notifier)
            .create(
              name: _nameController.text.trim(),
              type: _type,
              institution: _institutionController.text.trim(),
              openingBalanceMinor: openingBalanceMinor,
              // Not a form field: it comes from the statement that proposed the
              // account, and binds it so later imports match exactly.
              ofxAccountId: widget.prefill?.ofxAccountId,
              // Likewise the statement's `CURDEF`. Sent only when the file
              // declares one — otherwise the backend keeps defaulting to the
              // user's currency, which is what every hand-made account gets.
              currency: widget.prefill?.currency,
            );
      }
      if (mounted) Navigator.of(context).pop(created);
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
    if (value == null || value.trim().isEmpty) {
      return l10n.accountOpeningBalanceRequired;
    }
    try {
      NumberFormat.decimalPattern(
        Localizations.localeOf(context).toString(),
      ).parse(value.trim());
      return null;
    } on FormatException {
      return l10n.accountOpeningBalanceInvalid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The account's own currency when it has one, else the one its source
    // declares (an OFX `CURDEF`), else the profile's. The statement outranks the
    // profile because it is stating a fact about the account it describes, where
    // the profile is only the default we fall back to when nothing declares one.
    final currency =
        widget.initial?.currency ??
        widget.prefill?.currency ??
        ref.watch(currentUserProvider)?.currency ??
        '';
    // Only meaningful for the figure the statement itself declares: a date
    // without a balance to date says nothing about what the user is typing.
    final balanceAsOf = _balanceFromStatement
        ? widget.prefill?.balanceAsOf
        : null;

    return AppModal(
      width: 480,
      title: _isEditing
          ? l10n.accountFormEditTitle
          : l10n.accountFormCreateTitle,
      actions: [
        TextButton(
          key: const Key('accountFormCancelButton'),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.accountFormCancel),
        ),
        PrimaryButton(
          key: const Key('accountFormSubmitButton'),
          label: _isEditing
              ? l10n.accountFormSubmitEdit
              : l10n.accountFormSubmitCreate,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEditing && widget.prefill != null) ...[
              InlineBanner(
                key: const Key('accountFormPrefillNote'),
                message: l10n.accountFormPrefilledNote,
                tone: BannerTone.info,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
              child: AppSelect<AccountType>(
                key: const Key('accountTypeField'),
                value: _type,
                items: [
                  for (final type in AccountType.values)
                    AppSelectItem(
                      value: type,
                      label: accountTypeLabel(l10n, type),
                    ),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              // The same stored figure, named for what it means at each end of
              // the account's life: on creation there is no history behind it,
              // so what the user types is the balance the account holds today —
              // which is also what a statement's account block reports. Once
              // transactions land on top, it is only where the account started.
              //
              // A statement that dates its balance gets that date in the label:
              // the file's closing balance was current on the day it was cut,
              // and calling a three-week-old figure "solde actuel" invites the
              // user to correct it to today's — which is exactly the number the
              // first import must not be given.
              label: _isEditing
                  ? l10n.accountOpeningBalanceLabel
                  : balanceAsOf != null
                  ? l10n.accountBalanceAsOfLabel(balanceAsOf)
                  : l10n.accountCurrentBalanceLabel,
              // On create from a statement that declares its balance, the figure
              // is the statement's and is shown as settled — the note says where
              // it came from. A statement without one leaves the field empty and
              // editable, so the note reassures instead: a rough entry costs
              // nothing, since the first import derives the real figure anyway.
              // On edit, changing it is itself the correction, so the note
              // explains its blast radius: cache and snapshots move with it, but
              // no transaction is touched.
              helper: _isEditing
                  ? l10n.accountOpeningBalanceEditNote
                  : _balanceFromStatement
                  ? l10n.accountBalanceFromStatementNote
                  : widget.prefill != null
                  ? l10n.accountBalanceStatementNote
                  : null,
              // The currency rides at the end of the amount rather than in a
              // field of its own: it is a unit, not a value the form is asking
              // for, and a whole labelled row — dashed plate, lock glyph and all
              // — spent on three unchangeable letters read as a question the
              // user had to answer. Here it simply says what the figure beside
              // it is denominated in, which is the only thing it ever meant.
              child: _balanceFromStatement
                  ? ReadOnlyField(
                      key: const Key('accountOpeningBalanceField'),
                      value: _openingBalanceController.text,
                      suffix: currency,
                    )
                  : TextFormField(
                      key: const Key('accountOpeningBalanceField'),
                      controller: _openingBalanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      // A form value is a neutral figure, not a movement, so it
                      // keeps the primary text color rather than a sign color.
                      style: tabularNumberStyle(
                        Theme.of(context).textTheme.bodyLarge!,
                      ),
                      decoration: InputDecoration(
                        suffixText: currency,
                        suffixStyle: fieldSuffixStyle(context),
                      ),
                      validator: (value) =>
                          _validateOpeningBalance(value, l10n),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledField(
              label: l10n.accountInstitutionLabel,
              helper: _institutionFromStatement
                  ? l10n.accountInstitutionFromStatementNote
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: _institutionFromStatement
                        ? ReadOnlyField(
                            key: const Key('accountInstitutionField'),
                            value: _institution,
                          )
                        : TextFormField(
                            key: const Key('accountInstitutionField'),
                            controller: _institutionController,
                            onChanged: (value) =>
                                setState(() => _institution = value),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? l10n.accountInstitutionRequired
                                : null,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  // Live for a typed name, confirmation for a declared one:
                  // either way the user sees the chip the account will carry.
                  InstitutionAvatar(name: _institution, size: 40),
                ],
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
