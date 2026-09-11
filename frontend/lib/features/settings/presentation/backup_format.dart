import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/backup.dart';

/// A backup instant as « 11/09/2026 à 14:32 », in local time and [locale].
String formatBackupInstant(AppLocalizations l10n, String locale, DateTime at) {
  final local = at.toLocal();
  return l10n.settingsBackupDateTime(
    DateFormat.yMd(locale).format(local),
    DateFormat.Hm(locale).format(local),
  );
}

String backupFailureMessage(AppLocalizations l10n, BackupFailure failure) =>
    switch (failure) {
      BackupFailure.tooNew => l10n.settingsBackupErrorTooNew,
      BackupFailure.invalid => l10n.settingsBackupErrorInvalid,
      BackupFailure.currencyMismatch => l10n.settingsBackupErrorCurrency,
      BackupFailure.runActive => l10n.settingsBackupErrorRunActive,
      BackupFailure.conflict => l10n.settingsBackupErrorConflict,
      BackupFailure.unknown => l10n.settingsBackupErrorUnknown,
    };
