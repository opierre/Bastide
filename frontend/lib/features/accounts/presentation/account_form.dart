import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../core/session/current_user_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/app_segmented.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/institution_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/note_line.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/accounts_controller.dart';
import '../application/settlement_account.dart';
import '../domain/account.dart';
import 'account_error_localizer.dart';
import 'account_type_label.dart';
import 'settlement_rule_dialog.dart';

/// Opens the create/edit account modal.
///
/// Resolves to the account that was created, or `null` when the user cancelled
/// or was editing — so a caller that opened the form to fill a gap (the imports
/// panel, needing an account for the statement it holds) can carry on with it.
///
/// A deferred card just created is offered its settlement rule straight away:
/// until it has one, its monthly debit counts as spending on top of its
/// purchases. Unless [offerSettlementRule] is false — the imports panel creates
/// a card before importing its statement, and the rule's start date is read
/// from that statement's history, so the panel offers the rule afterwards.
Future<Account?> showAccountForm(
  BuildContext context, {
  Account? initial,
  AccountPrefill? prefill,
  bool offerSettlementRule = true,
}) async {
  final created = await showAppModal<Account>(
    context: context,
    builder: (_) => AccountForm(initial: initial, prefill: prefill),
  );
  if (offerSettlementRule &&
      created != null &&
      created.type == AccountType.deferredCard &&
      context.mounted) {
    await showSettlementRuleDialog(context, created, proposed: true);
  }
  return created;
}

/// Create/edit modal. The balance field means something different at each end
/// of the account's life (see [_AccountFormState]) but is editable at both —
/// on `PATCH` it is a manual correction, shifting the cached balance and every
/// saved snapshot by the delta rather than being treated as a fresh figure
/// (see the backend's `shift_opening_balance`). Currency is never editable and
/// is not a field of its own — it rides as the balance's suffix, taken from the
/// account, else from the statement's `CURDEF`, else from the profile (one
/// currency per user — see the multi-currency skill).
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
  /// than at field-init time because it must use the locale [parseMoneyMinor]
  /// re-parses with on submit, which needs `context` — unavailable before the
  /// widget is mounted.
  bool _openingBalanceFilled = false;

  late AccountType _type =
      widget.initial?.type ??
      widget.prefill?.type ??
      (widget.prefill?.isCardStatement ?? false
          ? AccountType.deferredCard
          : AccountType.checking);

  /// Mirrors the institution field so the logo preview updates as it is typed.
  late String _institution =
      widget.initial?.institution ?? widget.prefill?.institution ?? '';

  /// The settlement account the user picked, or the one they were given —
  /// `null` until either, in which case [_settlementAccountIdFor] proposes one.
  late String? _settlementAccountId =
      widget.initial?.settlementAccountId ??
      widget.prefill?.settlementAccountId;
  String? _settlementError;

  bool _isSubmitting = false;
  String? _errorText;

  /// The user has changed something: the scrim no longer closes the form,
  /// and « Annuler » asks before dropping it (`00` §7 « Modal », Closing).
  bool _dirty = false;

  bool get _isEditing => widget.initial != null;

  /// The statement declared a closing balance, so the balance field states it
  /// rather than asking for it.
  bool get _balanceFromStatement =>
      !_isEditing && widget.prefill?.balanceMinor != null;

  /// A card statement can't say how the card is debited, and the two answers
  /// book very differently — a deferred-debit card is settled in one lump on
  /// the current account each month — so the form puts that question in
  /// place of the type list.
  bool get _asksCardDebit =>
      !_isEditing && (widget.prefill?.isCardStatement ?? false);

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
    _openingBalanceController.text = formatMoneyInput(balanceMinor, locale);
    _openingBalanceFilled = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  /// The candidates for this card's settlement account.
  List<Account> _settlementCandidates() => settlementCandidates(
    ref.read(accountsControllerProvider).value ?? const [],
    cardId: widget.initial?.id,
    currentId: widget.initial?.settlementAccountId,
  );

  /// The settlement account the form stands on: the one picked or given, else
  /// the obvious one if there is one.
  String? _settlementAccountIdFor(List<Account> candidates) =>
      _settlementAccountId ??
      proposedSettlementAccountId(candidates, institution: _institution);

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;
    final isCard = _type == AccountType.deferredCard;
    final settlementAccountId = isCard
        ? _settlementAccountIdFor(_settlementCandidates())
        : null;
    setState(
      () => _settlementError = isCard && settlementAccountId == null
          ? l10n.accountSettlementRequired
          : null,
    );
    final valid = _formKey.currentState!.validate();
    if (!valid || _settlementError != null) return;

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
          : parseMoneyMinor(
              _openingBalanceController.text,
              locale,
              allowNegative: true,
            )!;

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
              settlementAccountId: settlementAccountId,
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
              settlementAccountId: settlementAccountId,
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

  String? _validateOpeningBalance(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.accountOpeningBalanceRequired;
    }
    final minor = parseMoneyMinor(
      value,
      Localizations.localeOf(context).toString(),
      allowNegative: true,
    );
    return minor == null ? l10n.accountOpeningBalanceInvalid : null;
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
    final isCard = _type == AccountType.deferredCard;
    const gap = SizedBox(height: AppSpacing.fieldGap);

    // « Débit de la carte »: how a card is debited. A card statement can't
    // say, so on creation from one it stands in place of the type list;
    // otherwise the type « Carte à débit différé » adds it under the
    // institution (proposal v6, `m-accounts`).
    final cardDebit = LabeledField(
      label: l10n.accountCardDebitLabel,
      helper: l10n.accountCardDebitHelper,
      child: AppSegmented<AccountType>(
        key: const Key('accountCardDebitField'),
        value: _type,
        segments: [
          AppSegment(
            key: const Key('accountCardDebitDeferred'),
            value: AccountType.deferredCard,
            label: l10n.accountCardDebitDeferred,
          ),
          AppSegment(
            key: const Key('accountCardDebitCredit'),
            value: AccountType.credit,
            label: l10n.accountCardDebitCredit,
          ),
        ],
        onChanged: (value) => setState(() {
          _type = value;
          _dirty = true;
        }),
      ),
    );

    return AppModal(
      key: const Key('accountFormModal'),
      width: AppModalSizes.w480,
      title: _isEditing
          ? l10n.accountFormEditTitle
          : l10n.accountFormCreateTitle,
      dirty: _dirty,
      busy: _isSubmitting,
      saveError: _errorText,
      onSubmit: _submit,
      actions: [
        const AppModalCancel(key: Key('accountFormCancelButton')),
        PrimaryButton(
          key: const Key('accountFormSubmitButton'),
          label: l10n.accountFormSubmitEdit,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        // Typed input makes the form dirty: the scrim no longer closes it.
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Something to know, not to act on: a note, not a banner.
            if (!_isEditing && widget.prefill != null) ...[
              NoteLine(
                key: const Key('accountFormPrefillNote'),
                text: l10n.accountFormPrefilledNote,
                icon: LucideIcons300.fileText,
              ),
              gap,
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
            gap,
            if (_asksCardDebit)
              cardDebit
            else
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
                  onChanged: (value) => setState(() {
                    _type = value;
                    _dirty = true;
                  }),
                ),
              ),
            gap,
            LabeledField(
              label: l10n.accountInstitutionLabel,
              helper: _institutionFromStatement
                  ? l10n.accountInstitutionFromStatementNote
                  : null,
              // The monogram sits inside the field (`05-accounts.md` §States):
              // live for a typed name, confirmation for a declared one, either
              // way the chip the account will carry.
              child: _institutionFromStatement
                  ? Row(
                      children: [
                        Expanded(
                          child: ReadOnlyField(
                            key: const Key('accountInstitutionField'),
                            value: _institution,
                          ),
                        ),
                        InstitutionAvatar(name: _institution),
                      ],
                    )
                  : TextFormField(
                      key: const Key('accountInstitutionField'),
                      controller: _institutionController,
                      onChanged: (value) =>
                          setState(() => _institution = value),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xsPlus,
                            end: AppSpacing.sm,
                          ),
                          child: InstitutionAvatar(
                            key: const Key('accountInstitutionMonogram'),
                            name: _institution,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.accountInstitutionRequired
                          : null,
                    ),
            ),
            if (isCard && !_asksCardDebit) ...[gap, cardDebit],
            if (isCard) ...[
              gap,
              _SettlementAccountField(
                candidates: settlementCandidates(
                  ref.watch(accountsControllerProvider).value ?? const [],
                  cardId: widget.initial?.id,
                  currentId: widget.initial?.settlementAccountId,
                ),
                selectedFor: _settlementAccountIdFor,
                errorText: _settlementError,
                onChanged: (id) => setState(() {
                  _settlementAccountId = id;
                  _settlementError = null;
                  _dirty = true;
                }),
              ),
            ],
            gap,
            LabeledField(
              // « Solde initial » (`05-accounts.md`, proposal v6): the figure
              // the account starts from. A statement that dates its balance
              // gets that date in the label instead: the file's closing
              // balance was current on the day it was cut, and naming the day
              // stops the user "correcting" it to today's figure, which is
              // exactly the number the first import must not be given.
              label: balanceAsOf != null
                  ? l10n.accountBalanceAsOfLabel(balanceAsOf)
                  : l10n.accountOpeningBalanceLabel,
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
              // The currency rides at the end of the amount, as a unit rather
              // than a value the form is asking for.
              child: _balanceFromStatement
                  ? ReadOnlyField(
                      key: const Key('accountOpeningBalanceField'),
                      value: _openingBalanceController.text,
                      suffix: currency,
                    )
                  : MoneyField(
                      key: const Key('accountOpeningBalanceField'),
                      controller: _openingBalanceController,
                      currency: currency,
                      // An overdrawn account opens below zero.
                      allowNegative: true,
                      validator: (value) =>
                          _validateOpeningBalance(value, l10n),
                    ),
            ),
            gap,
            // One currency per user (see the multi-currency skill): shown, never
            // asked for.
            LabeledField(
              label: l10n.accountCurrencyLabel,
              helper: l10n.accountCurrencyHelper,
              child: ReadOnlyField(
                key: const Key('accountCurrencyField'),
                value: l10n.accountCurrencyValue(currency),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The account a deferred card's monthly debit is drawn from. The debit is a
/// transfer between the two, and this is the only place the app learns which
/// two — so a card can't be saved without it.
class _SettlementAccountField extends StatelessWidget {
  const _SettlementAccountField({
    required this.candidates,
    required this.selectedFor,
    required this.errorText,
    required this.onChanged,
  });

  final List<Account> candidates;
  final String? Function(List<Account>) selectedFor;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = selectedFor(candidates);

    return LabeledField(
      label: l10n.accountSettlementLabel,
      helper: l10n.accountSettlementHelper,
      errorText: errorText,
      child: AppSelect<String?>(
        key: const Key('accountSettlementField'),
        value: selected,
        items: [
          if (selected == null)
            AppSelectItem(
              value: null,
              label: l10n.accountSettlementPlaceholder,
            ),
          for (final account in candidates)
            AppSelectItem(
              value: account.id,
              label: '${account.name} · ${account.institution}',
              leading: InstitutionAvatar(name: account.institution, size: 20),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
