import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/settings_store.dart';
import 'package:sextant/model/app_settings.dart';
import 'package:sextant/model/scan_protocol.dart';

void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sextant_settings_test');
    file = File('${tempDir.path}/settings.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('load() on a missing file returns defaults', () async {
    final settings = await SettingsStore(file).load();
    expect(settings, const AppSettings());
  });

  test('save() then load() round-trips every field', () async {
    final store = SettingsStore(file);
    const custom = AppSettings(
      themeMode: ThemeMode.light,
      monitorIntervalSeconds: 60,
      enabledProtocols: {ScanProtocol.tcp, ScanProtocol.mdns},
      historyEnabled: false,
      historyRetention: 100,
      vendorDbAutoRefresh: false,
      vendorDbRefreshIntervalDays: 7,
    );
    await store.save(custom);
    expect(await store.load(), custom);
  });

  test('a corrupt file falls back to defaults', () async {
    await file.create(recursive: true);
    await file.writeAsString('not json{{{');
    expect(await SettingsStore(file).load(), const AppSettings());
  });

  test('valid JSON of the wrong shape (an array) falls back to defaults',
      () async {
    await file.create(recursive: true);
    await file.writeAsString('[1, 2, 3]');
    expect(await SettingsStore(file).load(), const AppSettings());
  });

  test('a wrong-typed field (float where int expected) falls back to defaults',
      () async {
    await file.create(recursive: true);
    // A hand-edited file with a float where the loader does `as int?` would
    // throw a TypeError mid-parse; load() must still fall back, not crash.
    await file.writeAsString('{"monitorIntervalSeconds": 30.0}');
    expect(await SettingsStore(file).load(), const AppSettings());
  });
}
