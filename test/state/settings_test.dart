import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/app_settings.dart';
import 'package:sextant/model/scan_protocol.dart';
import 'package:sextant/state/settings.dart';

void main() {
  test('AppSettings defaults preserve today\'s hardcoded behavior', () {
    const settings = AppSettings();
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.monitorIntervalSeconds, 30);
    expect(settings.enabledProtocols, ScanProtocol.values.toSet());
    expect(settings.historyEnabled, isTrue);
    expect(settings.historyRetention, 500);
    expect(settings.vendorDbAutoRefresh, isTrue);
    expect(settings.vendorDbRefreshIntervalDays, 30);
  });

  group('settingsProvider', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sextant_settings_provider_test');
      container = ProviderContainer(overrides: [
        settingsFileDirProvider.overrideWith((ref) async => tempDir.path),
      ]);
      await container.read(settingsProvider.future);
    });

    tearDown(() async {
      container.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('setProtocolEnabled(false) removes a protocol from enabledProtocols',
        () async {
      await container
          .read(settingsProvider.notifier)
          .setProtocolEnabled(ScanProtocol.mdns, false);

      expect(
        container.read(settingsProvider).value!.enabledProtocols,
        isNot(contains(ScanProtocol.mdns)),
      );
    });

    test('setThemeMode persists and updates state', () async {
      await container
          .read(settingsProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(
        container.read(settingsProvider).value!.themeMode,
        ThemeMode.light,
      );
    });
  });
}
