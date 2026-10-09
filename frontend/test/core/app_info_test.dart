import 'package:bastide/core/app_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('appVersionProvider reads the version of the built app', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Bastide',
      packageName: 'bastide',
      version: '0.1.0',
      buildNumber: '42',
      buildSignature: '',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), '0.1.0');
  });
}
