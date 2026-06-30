// Major and minor are bumped manually at release time.
const kAppVersionMajor = 1;
const kAppVersionMinor = 17;

// Build number baked in at compile time via --dart-define=BUILD_NUMBER=N.
// CI sets this to the total git commit count (git rev-list --count HEAD),
// which is monotonically increasing and the same across CI providers.
// Local debug runs show 'dev'.
const kBuildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');

// "1.17" — shown in the toolbar.
String get kToolbarVersion => '$kAppVersionMajor.$kAppVersionMinor';

// "Version 1.17 build 42" — shown in the About dialog.
String get kAboutVersion => 'Version $kAppVersionMajor.$kAppVersionMinor build $kBuildNumber';
