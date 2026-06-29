import 'dart:convert';
import 'dart:io';

/// Persists a single integer build counter, incremented once per app launch
/// to drive the displayed `major.minor.build` version (see [formatVersion]
/// in `lib/version.dart`). Phase-1 JSON file, matching every other small
/// store in this app (e.g. `RenameStore`).
class BuildCounterStore {
  BuildCounterStore(this._file);

  final File _file;

  /// Reads the persisted counter (0 if the file is absent or corrupt),
  /// writes back the incremented value, and returns it.
  Future<int> loadAndIncrement() async {
    var value = 0;
    if (await _file.exists()) {
      try {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is int) value = decoded;
      } on FormatException {
        // Corrupt file: start clean rather than crash.
      }
    }
    final next = value + 1;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(next));
    return next;
  }
}
