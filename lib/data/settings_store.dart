import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../model/app_settings.dart';
import '../model/scan_protocol.dart';

/// Persists [AppSettings] as JSON. Phase-1 file store, matching every other
/// small store in this app (e.g. `RenameStore`): corrupt or missing files
/// fall back to defaults rather than crashing.
class SettingsStore {
  SettingsStore(this._file);

  final File _file;

  Future<AppSettings> load() async {
    if (!await _file.exists()) return const AppSettings();
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) return const AppSettings();
      return AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == decoded['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        monitorIntervalSeconds: decoded['monitorIntervalSeconds'] as int? ?? 30,
        enabledProtocols: {
          for (final name in (decoded['enabledProtocols'] as List? ?? []))
            ...ScanProtocol.values.where((p) => p.name == name),
        },
        historyEnabled: decoded['historyEnabled'] as bool? ?? true,
        historyRetention: decoded['historyRetention'] as int? ?? 500,
        vendorDbAutoRefresh: decoded['vendorDbAutoRefresh'] as bool? ?? true,
        vendorDbRefreshIntervalDays:
            decoded['vendorDbRefreshIntervalDays'] as int? ?? 30,
      );
    } catch (_) {
      // Any malformed settings file — invalid JSON (FormatException) or a
      // wrong-typed field, e.g. a hand-edited `"monitorIntervalSeconds": 30.0`
      // that fails an `as int?` cast (TypeError) — falls back to defaults
      // rather than crashing. settingsProvider's value is awaited by other
      // providers (scan/history/vendor lookups), so a throw here would cascade
      // into failed scans; defaults keep the app working.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode({
      'themeMode': settings.themeMode.name,
      'monitorIntervalSeconds': settings.monitorIntervalSeconds,
      'enabledProtocols': [
        for (final p in settings.enabledProtocols) p.name,
      ],
      'historyEnabled': settings.historyEnabled,
      'historyRetention': settings.historyRetention,
      'vendorDbAutoRefresh': settings.vendorDbAutoRefresh,
      'vendorDbRefreshIntervalDays': settings.vendorDbRefreshIntervalDays,
    }));
  }
}
