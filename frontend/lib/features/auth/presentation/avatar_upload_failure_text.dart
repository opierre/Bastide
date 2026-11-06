import '../../../l10n/app_localizations.dart';
import '../domain/avatar_picture.dart';

/// The localized reason a picture didn't become the avatar.
String avatarUploadFailureText(
  AppLocalizations l10n,
  AvatarUploadFailure failure,
) => switch (failure) {
  AvatarUploadFailure.tooLarge => l10n.settingsAvatarPictureTooLarge(
    maxAvatarUploadBytes ~/ (1024 * 1024),
  ),
  AvatarUploadFailure.invalidType => l10n.settingsAvatarPictureInvalid,
  AvatarUploadFailure.generic => l10n.settingsAvatarPictureError,
};
