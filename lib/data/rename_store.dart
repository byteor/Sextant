import 'dart:convert';
import 'dart:io';

/// Persists user-assigned device names (and, later, notes) keyed by device
/// identity — see [deviceIdentity]. A device's custom name therefore follows it
/// across IP changes and re-scans.
///
/// Phase 1 uses a small JSON file; the relational scan-history store (Drift)
/// that arrives in a later phase will subsume this for richer querying.
class RenameStore {
  RenameStore(this._file);

  final File _file;
  final Map<String, String> _names = {};

  /// Loads persisted names into memory. Safe to call when the file is absent.
  Future<void> load() async {
    if (!await _file.exists()) return;
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map) {
        _names
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry('$k', '$v')));
      }
    } on FormatException {
      // Corrupt file: start clean rather than crash.
    }
  }

  String? nameFor(String identity) => _names[identity];

  Map<String, String> get all => Map.unmodifiable(_names);

  /// Sets (or, when [name] is null/empty, clears) the name for [identity] and
  /// writes through to disk.
  Future<void> setName(String identity, String? name) async {
    if (name == null || name.trim().isEmpty) {
      _names.remove(identity);
    } else {
      _names[identity] = name.trim();
    }
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_names));
  }
}
