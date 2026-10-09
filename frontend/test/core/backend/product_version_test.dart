import 'package:bastide/core/backend/product_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same version matches', () {
    expect(sameProductVersion('0.1.0', '0.1.0'), isTrue);
  });

  test('build metadata is ignored', () {
    expect(sameProductVersion('0.1.0+42', '0.1.0'), isTrue);
  });

  test('SemVer and PEP 440 spellings of one pre-release match', () {
    expect(sameProductVersion('0.2.0-rc.1', '0.2.0rc1'), isTrue);
  });

  test('different versions do not', () {
    expect(sameProductVersion('0.2.0', '0.1.0'), isFalse);
    expect(sameProductVersion('0.2.0-rc.1', '0.2.0rc2'), isFalse);
    expect(sameProductVersion('0.2.0-rc.1', '0.2.0'), isFalse);
  });
}
