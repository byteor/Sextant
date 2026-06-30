import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/version.dart';

void main() {
  test('kToolbarVersion is major.minor', () {
    expect(kToolbarVersion, '$kAppVersionMajor.$kAppVersionMinor');
  });

  test('kAboutVersion starts with Version major.minor build', () {
    expect(
      kAboutVersion,
      startsWith('Version $kAppVersionMajor.$kAppVersionMinor build '),
    );
  });

  test('kBuildNumber defaults to dev in test runs (no --dart-define set)', () {
    expect(kBuildNumber, 'dev');
  });
}
