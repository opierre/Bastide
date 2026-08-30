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
AccountType? accountTypeFromOfx(String? ofxType) => switch (ofxType?.toUpperCase()) {
  'CHECKING' || 'MONEYMRKT' => AccountType.checking,
  'SAVINGS' => AccountType.savings,
  'CREDITCARD' || 'CREDITLINE' => AccountType.credit,
  _ => null,
};

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

  final byNumber = accounts.where((a) => _carriesNumber(a, info.accountNumber)).toList();
  if (byNumber.length == 1) return OfxAccountMatched(info, byNumber.single);

  final institution = info.institutionLabel;
  if (institution == null) return OfxAccountUnmatched(info);

  final sameBank = accounts
      .where((account) => _sameInstitution(account.institution, institution))
      .toList();
  if (sameBank.isEmpty) return OfxAccountUnmatched(info);

  final type = accountTypeFromOfx(info.accountType);
  final sameType = sameBank.where((account) => account.type == type).toList();
  final candidates = sameType.length == 1 ? sameType : sameBank;

  return candidates.length == 1
      ? OfxAccountMatched(info, candidates.single)
      : OfxAccountAmbiguous(info, candidates);
}

/// The verdict for the staged file, or `null` when there is no file staged to
/// have a verdict about.
///
/// Since the panel dropped its destination selector, this is what decides where
/// an import goes: [OfxAccountMatched] carries the account, and every other
/// case is a question the panel has to put to the user before it can import.
class OfxAccountDetection extends Notifier<OfxAccountMatch?> {
  @override
  OfxAccountMatch? build() => null;

  /// Reads [file] and resolves it against [accounts]. Returns the verdict so
  /// the caller can act on it (import into the account, or offer to create it)
  /// without re-reading state it just wrote.
  ///
  /// Asynchronous because a statement that names no bank still carries its bank
  /// code, and the backend's directory is what turns that code into a name —
  /// which both the matcher and the account it proposes are better for.
  Future<OfxAccountMatch> detect(PickedImportFile file, List<Account> accounts) async {
    var info = parseOfxAccountInfo(file.bytes);
    if (info == null) return state = const OfxAccountUnreadable();

    // Only worth asking when the file didn't already name its bank.
    final bankId = info.bankId;
    if (info.organization == null && bankId != null) {
      info = info.withBankName(await ref.read(banksRepositoryProvider).nameForCode(bankId));
    }

    return state = matchOfxAccount(info, accounts);
  }

  /// Records that [account] — just created from [info] — is this statement's
  /// account, so the panel stops offering to create it.
  void resolveTo(OfxAccountInfo info, Account account) =>
      state = OfxAccountMatched(info, account);

  void clear() => state = null;
}

final ofxAccountDetectionProvider =
    NotifierProvider<OfxAccountDetection, OfxAccountMatch?>(OfxAccountDetection.new);
