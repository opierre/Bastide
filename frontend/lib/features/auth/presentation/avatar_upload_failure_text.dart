import '../../../l10n/app_localizations.dart';
import '../../../core/pictures/pictures.dart';

/// The localized reason a picture didn't become the avatar.
String avatarUploadFailureText(
  AppLocalizations l10n,
  PictureUploadFailure failure,
) => switch (failure) {
  PictureUploadFailure.tooLarge => l10n.settingsAvatarPictureTooLarge(
    maxPictureUploadBytes ~/ (1024 * 1024),
  ),
  PictureUploadFailure.invalidType => l10n.settingsAvatarPictureInvalid,
  PictureUploadFailure.generic => l10n.settingsAvatarPictureError,
};
