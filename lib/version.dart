/// The app's manually-bumped major/minor version. The third component of the
/// displayed version ("the build number") auto-increments on every app
/// launch — see [BuildCounterStore].
const kAppVersionMajor = 1;
const kAppVersionMinor = 0;

/// Formats the full displayed version as `major.minor.build`, e.g. `1.0.47`.
String formatVersion(int build) =>
    '$kAppVersionMajor.$kAppVersionMinor.$build';
