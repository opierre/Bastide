/// The application version, shown in Settings › À propos.
///
/// Mirrors `version:` in `pubspec.yaml` by hand. Reading it at runtime would
/// mean taking on `package_info_plus` and a platform channel for one string;
/// keep the two in step when bumping the release.
const appVersion = '0.1.0';
