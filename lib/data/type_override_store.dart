import 'dart:convert';
import 'dart:io';

import '../model/discovery_source.dart';

/// Persists a user-chosen device *type* keyed by device identity — see
/// [deviceIdentity]. A manual type therefore overrides automatic classification
/// and follows the device across IP changes and re-scans (including live
/// monitoring, which would otherwise re-classify it every pass).
class TypeOverrideStore {
  TypeOverrideStore(this._file);

  final File _file;
  final Map<String, DeviceType> _types = {};

  Future<void> load() async {
    if (!await _file.exists()) return;
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map) {
        _types.clear();
        decoded.forEach((key, value) {
          final type = _parseType('$value');
          if (type != null) _types['$key'] = type;
        });
      }
    } on FormatException {
      // Corrupt file: start clean rather than crash.
    }
  }

  DeviceType? typeFor(String identity) => _types[identity];

  /// Sets (or, when [type] is null, clears) the manual type for [identity] and
  /// writes through to disk.
  Future<void> setType(String identity, DeviceType? type) async {
    if (type == null) {
      _types.remove(identity);
    } else {
      _types[identity] = type;
    }
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(_types.map((k, v) => MapEntry(k, v.name))),
    );
  }

  static DeviceType? _parseType(String name) {
    for (final t in DeviceType.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
