import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/account.dart';
import '../../banks/data/banks_repository.dart';
import '../data/ofx_account_parser.dart';
import '../domain/ofx_account_info.dart';
import 'imports_controller.dart';

/// What the staged statement says about its account, resolved against the
/// accounts the user already has.
///
/// This is the panel's only source of a destination: there is no account
/// selector to fall back on, so every case here either names the account
/// outright or says exactly what the user still has to settle.
sealed class OfxAccountMatch {
  const OfxAccountMatch();
}

/// One account is clearly the destination — the panel imports into it, with
/// nothing left for the user to settle.
class OfxAccountMatched extends OfxAccountMatch {
  const OfxAccountMatched(this.info, this.account);

  /// The account block read from the file.
  final OfxAccountInfo info;

  final Account account;
}

/// The file points at a bank the user has several accounts with, and nothing
/// in the file separates them. We refuse to guess: creating an account here
/// would duplicate one, and picking one could file transactions in the wrong
/// place, so the panel asks — over these candidates only.
class OfxAccountAmbiguous extends OfxAccountMatch {
  const OfxAccountAmbiguous(this.info, this.candidates);

  /// The account block read from the file.
  final OfxAccountInfo info;

  final List<Account> candidates;
}

/// No account looks like this statement's — offer to create it.
class OfxAccountUnmatched extends OfxAccountMatch {
  const OfxAccountUnmatched(this.info);

  /// The account block read from the file.
  final OfxAccountInfo info;
}

/// The file declares no account we can read — not OFX at all, or an exporter
/// that omits `ACCTID`.
///
/// Nothing can be matched or proposed from a file that names no account, so
/// this is the one case where the user still picks from the full list. It is a
/// fallback for a malformed file, not the normal path: a well-formed statement
/// always lands in one of the cases above.
class OfxAccountUnreadable extends OfxAccountMatch {
  const OfxAccountUnreadable();
}

/// Casefolded, punctuation-free form used to compare bank names typed by hand
/// against bank names emitted by a bank ("BNP Paribas" vs "BNP PARIBAS.").
@visibleForTesting
String normalizeInstitution(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Whether two institution labels denote the same bank. Containment counts,
/// because the file's `ORG` is often a longer legal name than the one the user
/// typed ("BOURSORAMA BANQUE" vs "Boursorama"), but only above a few
/// characters — a two-letter overlap means nothing.
bool _sameInstitution(String a, String b) {
  final left = normalizeInstitution(a);
  final right = normalizeInstitution(b);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  final shorter = left.length <= right.length ? left : right;
  final longer = left.length <= right.length ? right : left;
  return shorter.length >= 4 && longer.contains(shorter);
}

/// Maps the OFX account-type literal onto ours.
///
/// A card statement maps to [AccountType.deferredCard]: a French bank that
/// exports a card on its own statement is almost always reporting the holding
/// account of a deferred-debit card, revolving credit cards being rare there.
/// It is only the proposal — the account form asks the user to confirm it.
AccountType? accountTypeFromOfx(String? ofxType) =>
    switch (ofxType?.toUpperCase()) {
      'CHECKING' || 'MONEYMRKT' => AccountType.checking,
      'SAVINGS' => AccountType.savings,
      'CREDITCARD' => AccountType.deferredCard,
      'CREDITLINE' => AccountType.credit,
      _ => null,
    };

/// Whether an account of [type] can be the one a statement of [ofxType]
/// describes. A card statement fits either card type, since the file can't
/// tell them apart and the user settled it when the account was created.
bool _typeFits(AccountType type, String? ofxType) {
  if (ofxType?.toUpperCase() == 'CREDITCARD') {
    return type == AccountType.deferredCard || type == AccountType.credit;
  }
  return type == accountTypeFromOfx(ofxType);
}

/// Every digit run in [value], so an account number can be recognized inside a
/// free-text account name ("Courant ••4567", "Livret A 12345678").
Iterable<String> _digitRuns(String value) =>
    RegExp(r'\d+').allMatches(value).map((match) => match.group(0)!);

/// Whether [account] is named after [number] — the whole number, or the last
/// four digits people usually keep.
bool _carriesNumber(Account account, String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return false;
  final tail = digits.substring(digits.length - 4);
  for (final run in _digitRuns('${account.name} ${account.institution}')) {
    if (run == digits || (run.length >= 4 && run.endsWith(tail))) return true;
  }
  return false;
}

/// Resolves [info] against [accounts], most specific evidence first: the bank
/// account id the account was bound to, then the number read out of its name,
/// then bank plus type, then bank alone.
///
/// Kept as a pure function so the rule is testable on its own — the widget only
/// reacts to the verdict.
OfxAccountMatch matchOfxAccount(OfxAccountInfo info, List<Account> accounts) {
  // An account created from a statement carries that statement's ACCTID, so
  // this is an identity, not a heuristic: it settles the question outright.
  for (final account in accounts) {
    if (account.ofxAccountId == info.accountNumber.trim()) {
      return OfxAccountMatched(info, account);
    }
  }

  final byNumber = accounts
      .where((a) => _carriesNumber(a, info.accountNumber))
      .toList();
  if (byNumber.length == 1) return OfxAccountMatched(info, byNumber.single);

  final institution = info.institutionLabel;
  if (institution == null) return OfxAccountUnmatched(info);

  final sameBank = accounts
      .where((account) => _sameInstitution(account.institution, institution))
      .toList();
  if (sameBank.isEmpty) return OfxAccountUnmatched(info);

  final sameType = sameBank
      .where((account) => _typeFits(account.type, info.accountType))
      .toList();
  final candidates = sameType.length == 1 ? sameType : sameBank;

  return candidates.length == 1
      ? OfxAccountMatched(info, candidates.single)
      : OfxAccountAmbiguous(info, candidates);
}

/// Resolves every statement of a file at once, so two statements never settle
/// on the same account.
///
/// Identity first: a statement whose ACCTID an account is bound to claims it
/// outright, and the other statements are matched only against what is left.
/// Two statements whose evidence still points at one account (two Livrets at a
/// bank where the user has a single account) both become ambiguous rather than
/// importing one of them into the wrong place.
List<OfxAccountMatch> matchOfxStatements(
  List<OfxAccountInfo> statements,
  List<Account> accounts,
) {
  final matches = List<OfxAccountMatch?>.filled(statements.length, null);
  final claimed = <String>{};
  for (var i = 0; i < statements.length; i++) {
    final number = statements[i].accountNumber.trim();
    for (final account in accounts) {
      if (account.ofxAccountId == number && claimed.add(account.id)) {
        matches[i] = OfxAccountMatched(statements[i], account);
        break;
      }
    }
  }

  final free = accounts.where((a) => !claimed.contains(a.id)).toList();
  for (var i = 0; i < statements.length; i++) {
    matches[i] ??= matchOfxAccount(statements[i], free);
  }

  final guessed = <String, int>{};
  for (final match in matches) {
    if (match is OfxAccountMatched && !claimed.contains(match.account.id)) {
      guessed.update(match.account.id, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return [
    for (final match in matches.cast<OfxAccountMatch>())
      if (match is OfxAccountMatched && (guessed[match.account.id] ?? 0) > 1)
        OfxAccountAmbiguous(match.info, [
          for (final account in free)
            if (account.id == match.account.id ||
                _sameInstitution(
                  account.institution,
                  match.info.institutionLabel ?? '',
                ))
              account,
        ])
      else
        match,
  ];
}

/// The account a card statement's card is most likely settled from, read from
/// the file it came in: the bank account a sibling statement resolved to.
///
/// Banks export a card with the account it is drawn from, so a sibling of the
/// same bank — the code the card borrowed from it — is the answer; failing
/// that, the file's only bank account. `null` when the file says nothing either
/// way, and the form proposes from the user's accounts instead.
Account? settlingAccountFor(
  OfxAccountInfo card,
  List<OfxAccountMatch> matches,
) {
  final banks = [
    for (final match in matches)
      if (match case OfxAccountMatched(
        :final info,
        :final account,
      ) when !info.isCardStatement && account.type != AccountType.deferredCard)
        (info: info, account: account),
  ];
  final sameBank = [
    for (final bank in banks)
      if (card.bankId != null && bank.info.bankId == card.bankId) bank.account,
  ];
  if (sameBank.length == 1) return sameBank.single;
  return banks.length == 1 ? banks.single.account : null;
}

/// The verdicts for the staged file — one per statement it holds — or `null`
/// when there is no file staged to have a verdict about.
///
/// Since the panel dropped its destination selector, this is what decides where
/// an import goes: [OfxAccountMatched] carries the account, and every other
/// case is a question the panel has to put to the user before it can import.
/// A file naming no account at all is the single [OfxAccountUnreadable].
class OfxAccountDetection extends Notifier<List<OfxAccountMatch>?> {
  @override
  List<OfxAccountMatch>? build() => null;

  /// Reads [file] and resolves its statements against [accounts]. Returns the
  /// verdicts so the caller can act on them (offer to create the accounts the
  /// file names) without re-reading state it just wrote.
  ///
  /// Asynchronous because a statement that names no bank still carries its bank
  /// code, and the backend's directory is what turns that code into a name —
  /// which both the matcher and the account it proposes are better for.
  Future<List<OfxAccountMatch>> detect(
    PickedImportFile file,
    List<Account> accounts,
  ) async {
    final statements = parseOfxStatements(file.bytes);
    if (statements.isEmpty) return state = const [OfxAccountUnreadable()];

    final named = [
      for (final info in statements)
        // Only worth asking when the file didn't already name its bank.
        if (info.organization == null && info.bankId != null)
          info.withBankName(
            await ref.read(banksRepositoryProvider).nameForCode(info.bankId!),
          )
        else
          info,
    ];

    return state = matchOfxStatements(named, accounts);
  }

  /// Records that [account] — just created from [info] — is that statement's
  /// account, so the panel stops offering to create it.
  void resolveTo(OfxAccountInfo info, Account account) {
    final current = state;
    if (current == null) return;
    state = [
      for (final match in current)
        if (statementKey(match) == info.accountNumber)
          OfxAccountMatched(info, account)
        else
          match,
    ];
  }

  void clear() => state = null;
}

/// The statement a verdict is about, as the backend names it: its `ACCTID`, or
/// `null` for a file that names no account.
String? statementKey(OfxAccountMatch match) => switch (match) {
  OfxAccountMatched(:final info) ||
  OfxAccountAmbiguous(:final info) ||
  OfxAccountUnmatched(:final info) => info.accountNumber,
  OfxAccountUnreadable() => null,
};

final ofxAccountDetectionProvider =
    NotifierProvider<OfxAccountDetection, List<OfxAccountMatch>?>(
      OfxAccountDetection.new,
    );
