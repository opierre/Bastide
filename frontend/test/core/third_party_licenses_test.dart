import 'package:bastide/core/third_party_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Lucide ISC notice is bundled and registered', () async {
    registerThirdPartyLicenses();

    final lucide = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Lucide'))
        .toList();

    expect(lucide, hasLength(1));
    final text = lucide.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('ISC License'));
    expect(text, contains('Lucide Icons and Contributors'));
  });
}
