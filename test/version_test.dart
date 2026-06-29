import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/version.dart';

void main() {
  test('formatVersion joins major, minor, and build with dots', () {
    expect(formatVersion(47), '1.0.47');
  });

  test('formatVersion uses kAppVersionMajor/kAppVersionMinor', () {
    expect(formatVersion(0), '$kAppVersionMajor.$kAppVersionMinor.0');
  });
}
