import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/scan_protocol.dart';
import 'package:sextant/state/settings.dart';
import 'package:sextant/ui/settings_screen.dart';

void main() {
  // settingsProvider's build() (and setThemeMode's persistence write) do
  // real dart:io File/Directory operations. Those must run via
  // tester.runAsync() — flutter_test's fake-async zone never resolves real
  // IO Futures — and the provider must be pre-warmed (read once inside
  // runAsync) *before* any widget pump triggers ref.watch(settingsProvider)
  // for the first time; once build() starts on the fake-async zone, no
  // later runAsync call can rescue that already-pending Future.
  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    // The Settings screen's sections stack taller than the default 800x600
    // test surface; without a taller surface the lazy ListView never builds
    // the lower sections (History, Vendor database), so their widgets can't
    // be found. Widen the *test* surface only — production layout scrolls.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('sextant_settings_screen_test'),
    );
    addTearDown(() => tester.runAsync(() async {
          if (await tempDir!.exists()) await tempDir.delete(recursive: true);
        }));

    final container = ProviderContainer(overrides: [
      settingsFileDirProvider.overrideWith((ref) async => tempDir!.path),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() => container.read(settingsProvider.future));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('shows Light, Dark, and Auto theme options', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets('selecting Light updates settingsProvider', (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Light'));
    await tester.pump();
    // setThemeMode's state update is synchronous; its fire-and-forget
    // persistence write is real IO, given a turn on the real event loop so
    // it doesn't leak a pending Future past the test's end.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(container.read(settingsProvider).value!.themeMode, ThemeMode.light);
  });

  testWidgets('shows a toggle for every scan protocol', (tester) async {
    await pumpSettings(tester);
    for (final p in ScanProtocol.values) {
      expect(find.text(p.label), findsOneWidget);
    }
  });

  testWidgets('disabling a protocol updates settingsProvider', (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text(ScanProtocol.mdns.label));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(
      container.read(settingsProvider).value!.enabledProtocols,
      isNot(contains(ScanProtocol.mdns)),
    );
  });

  testWidgets('shows a history enable switch and a retention dropdown',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('Save scan history'), findsOneWidget);
    expect(find.text('500'), findsOneWidget); // default retention
  });

  testWidgets('turning history off updates settingsProvider', (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Save scan history'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(container.read(settingsProvider).value!.historyEnabled, isFalse);
  });
}
