import 'package:bastide/core/backend/data_dir.dart';
import 'package:flutter_test/flutter_test.dart';

/// The expected folders are platformdirs' `user_data_dir("Bastide",
/// appauthor=False, roaming=False)`, which is where the backend writes.
void main() {
  test('Windows: the local, not roaming, app data folder', () {
    expect(
      bastideDataDir(
        operatingSystem: 'windows',
        environment: {r'LOCALAPPDATA': r'C:\Users\ada\AppData\Local'},
      ),
      r'C:\Users\ada\AppData\Local\Bastide',
    );
  });

  test('macOS: Application Support', () {
    expect(
      bastideDataDir(
        operatingSystem: 'macos',
        environment: {'HOME': '/Users/ada'},
      ),
      '/Users/ada/Library/Application Support/Bastide',
    );
  });

  test('Linux: XDG_DATA_HOME first, then ~/.local/share', () {
    expect(
      bastideDataDir(
        operatingSystem: 'linux',
        environment: {'HOME': '/home/ada', 'XDG_DATA_HOME': '/data'},
      ),
      '/data/Bastide',
    );
    expect(
      bastideDataDir(
        operatingSystem: 'linux',
        environment: {'HOME': '/home/ada'},
      ),
      '/home/ada/.local/share/Bastide',
    );
  });

  test('none without a home to start from', () {
    expect(bastideDataDir(operatingSystem: 'linux', environment: {}), isNull);
  });
}
