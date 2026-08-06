import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/account.dart';
import '../data/ofx_account_parser.dart';
import '../domain/ofx_account_info.dart';
import 'imports_controller.dart';

/// What the staged statement says about its account, resolved against the
/// accounts the user already has.
sealed class OfxAccountMatch {
  const OfxAccountMatch(this.info);

  /// The account block read from the file.
  final OfxAccountInfo info;
}

/// One account is clearly the destination — the panel selects it.
class OfxAccountMatched extends OfxAccountMatch {
  const OfxAccountMatched(super.info, this.account);

  final Account account;
}

/// The file points at a bank the user has several accounts with, and nothing
/// in the file separates them. We refuse to guess: creating an account here
/// would duplicate one, and picking one could file transactions in the wrong
/// place, so the user chooses.
class OfxAccountAmbiguous extends OfxAccountMatch {
  const OfxAccountAmbiguous(super.info, this.candidates);

  final List<Account> candidates;
}

/// No account looks like this statement's — offer to create it.
class OfxAccountUnmatched extends OfxAccountMatch {
  const OfxAccountUnmatched(super.info);
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

/// The verdict for the staged file, or `null` when there is none to show — no
/// file staged, a CSV (which carries no account block), or an OFX we couldn't
/// read an account out of.
class OfxAccountDetection extends Notifier<OfxAccountMatch?> {
  @override
  OfxAccountMatch? build() => null;

  /// Reads [file] and resolves it against [accounts]. Returns the verdict so
  /// the caller can act on it (select the account, or offer to create it)
  /// without re-reading state it just wrote.
  OfxAccountMatch? detect(PickedImportFile file, List<Account> accounts) {
    if (file.needsCsvTemplate) return state = null;
    final info = parseOfxAccountInfo(file.bytes);
    return state = info == null ? null : matchOfxAccount(info, accounts);
  }

  /// Records that [account] — just created from [info] — is this statement's
  /// account, so the panel stops offering to create it.
  void resolveTo(OfxAccountInfo info, Account account) =>
      state = OfxAccountMatched(info, account);

  void clear() => state = null;
}

final ofxAccountDetectionProvider =
    NotifierProvider<OfxAccountDetection, OfxAccountMatch?>(OfxAccountDetection.new);
