import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/settings_store.dart';
import '../model/app_settings.dart';
import '../model/scan_protocol.dart';

/// The directory the settings file lives in. A seam so tests can point it at
/// a temp directory instead of the real app-support directory.
final settingsFileDirProvider = FutureProvider<String>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return dir.path;
});

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  SettingsStore? _store;

  @override
  Future<AppSettings> build() async {
    final dirPath = await ref.watch(settingsFileDirProvider.future);
    final store = SettingsStore(File('$dirPath/settings.json'));
    _store = store;
    return store.load();
  }

  Future<void> _update(AppSettings Function(AppSettings) updater) async {
    final current = state.value ?? const AppSettings();
    final next = updater(current);
    state = AsyncData(next);
    await _store?.save(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update((s) => s.copyWith(themeMode: mode));

  Future<void> setMonitorIntervalSeconds(int seconds) =>
      _update((s) => s.copyWith(monitorIntervalSeconds: seconds));

  Future<void> setProtocolEnabled(ScanProtocol protocol, bool enabled) =>
      _update((s) {
        final next = {...s.enabledProtocols};
        if (enabled) {
          next.add(protocol);
        } else {
          next.remove(protocol);
        }
        return s.copyWith(enabledProtocols: next);
      });

  Future<void> setHistoryEnabled(bool enabled) =>
      _update((s) => s.copyWith(historyEnabled: enabled));

  Future<void> setHistoryRetention(int retention) =>
      _update((s) => s.copyWith(historyRetention: retention));

  Future<void> setVendorDbAutoRefresh(bool enabled) =>
      _update((s) => s.copyWith(vendorDbAutoRefresh: enabled));

  Future<void> setVendorDbRefreshIntervalDays(int days) =>
      _update((s) => s.copyWith(vendorDbRefreshIntervalDays: days));
}
