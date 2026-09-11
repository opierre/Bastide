import '../../../l10n/app_localizations.dart';
import '../domain/database_reset.dart';

String resetFailureMessage(AppLocalizations l10n, ResetFailure failure) =>
    switch (failure) {
      // The same wait the backup restore asks for, and the same reason: one
      // categorisation run is writing to the rows this would delete.
      ResetFailure.runActive => l10n.settingsBackupErrorRunActive,
      ResetFailure.unknown => l10n.settingsResetErrorUnknown,
    };
