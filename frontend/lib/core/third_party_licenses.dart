import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Lucide notice, bundled as an asset (see `pubspec.yaml`).
const lucideLicenseAsset = 'assets/licenses/lucide/LICENSE';

/// Adds the notices Flutter can't collect on its own to [LicenseRegistry].
///
/// Flutter gathers each package's `LICENSE`, but the package that ships the
/// Lucide font (`lucide_icons_flutter`) carries only its own MIT licence. The
/// icons themselves are ISC, whose notice must appear in every copy, so the
/// app registers it itself.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(lucideLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Lucide'], text);
  });
}
