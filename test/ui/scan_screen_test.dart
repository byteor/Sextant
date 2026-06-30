import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/state/column_widths.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/state/scan_state.dart';
import 'package:sextant/state/settings.dart';
import 'package:sextant/ui/scan_screen.dart';

class _FixedScanController extends ScanController {
  _FixedScanController(this._state);
  final ScanState _state;

  @override
  ScanState build() => _state;
}

Device _dev(String ip) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, firstSeen: t, lastSeen: t);
}

Future<void> _pump(
  WidgetTester tester,
  List<Device> devices, {
  ScanState? state,
}) async {
  // The device table's fixed-width columns (plus the toolbar) need more
  // horizontal space than flutter_test's default 800x600 surface, which
  // would otherwise overflow the Row before this test gets to interact with
  // it. This only widens the *test* surface — production layout is
  // unaffected.
  await tester.binding.setSurfaceSize(const Size(1400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // settingsProvider's build() does real dart:io File/Directory operations
  // (via the settingsFileDirProvider override below), which never complete
  // if first triggered inside flutter_test's fake-async zone — they must run
  // via tester.runAsync() on the real event loop, and the provider must be
  // pre-warmed (read once inside runAsync) *before* any widget pump triggers
  // ref.watch(settingsProvider) for the first time, since the Settings
  // screen pushed by the toolbar's gear button watches it.
  final tempDir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('sextant_scan_screen_test'),
  );
  addTearDown(() => tester.runAsync(() async {
        if (await tempDir!.exists()) await tempDir.delete(recursive: true);
      }));

  final container = ProviderContainer(overrides: [
    scanControllerProvider.overrideWith(
      () => _FixedScanController(state ?? ScanState(devices: devices)),
    ),
    networksProvider.overrideWith((ref) async => []),
    // settingsProvider also reads the app-support directory via
    // path_provider — overridden so opening the Settings screen
    // (pushed on top of this widget tree) resolves deterministically.
    settingsFileDirProvider.overrideWith((ref) async => tempDir!.path),
  ]);
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(settingsProvider.future));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ScanScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('latestLatencyLabel', () {
    test('returns null for no readings', () {
      expect(latestLatencyLabel([]), isNull);
    });

    test('rounds the most recent reading to whole milliseconds', () {
      expect(latestLatencyLabel([4.2, 11.0, 12.6]), '13 ms');
    });

    test('shows "<1 ms" for sub-millisecond latency', () {
      expect(latestLatencyLabel([12.0, 0.4]), '<1 ms');
    });
  });

  group('ScanState.backgroundProgress', () {
    test('is 0 when the host count is not yet known (avoids divide-by-zero)',
        () {
      expect(const ScanState(backgroundTotal: 0).backgroundProgress, 0);
    });

    test('is scanned/total once the host count is known', () {
      expect(
        const ScanState(backgroundScanned: 3, backgroundTotal: 12)
            .backgroundProgress,
        0.25,
      );
    });
  });

  testWidgets('the version/About/Settings group is flush to the right edge',
      (tester) async {
    await _pump(tester, []);
    // The Settings button is the right-most toolbar item; it must sit flush
    // against the toolbar's right edge — only the AppBar's titleSpacing (16)
    // plus a few px of icon padding should separate it from the 1400px surface
    // edge (~20px measured). With the version text wrongly wrapped in Flexible
    // it competed with the Spacer for flex space and floated ~67px from the
    // edge instead.
    final settingsRight = tester.getTopRight(find.byTooltip('Settings')).dx;
    expect(1400 - settingsRight, lessThan(40));
  });

  testWidgets('a background monitor re-scan shows a determinate progress bar',
      (tester) async {
    await _pump(
      tester,
      [],
      state: const ScanState(
        isMonitoring: true,
        isBackgroundScanning: true,
        backgroundScanned: 3,
        backgroundTotal: 12,
      ),
    );

    final bar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(LinearProgressIndicator),
    );
    expect(bar, findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(bar).value, closeTo(0.25, 1e-9));
  });

  testWidgets('an idle (non-scanning) state shows no progress bar',
      (tester) async {
    await _pump(tester, []);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('there is no "Network map" button in the toolbar', (tester) async {
    await _pump(tester, []);

    expect(find.byTooltip('Network map'), findsNothing);
  });

  testWidgets('dragging the IP column resize handle widens it and narrows '
      'the Open ports filler correspondingly', (tester) async {
    await _pump(tester, [_dev('10.0.0.1')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    final before = container.read(columnWidthsProvider).ip;

    final handle = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    expect(handle, findsWidgets);

    await tester.drag(handle.first, const Offset(30, 0));
    await tester.pump();

    expect(container.read(columnWidthsProvider).ip, before + 30);
  });

  testWidgets('shrinking the IP column to its minimum ellipsizes the IP '
      'text instead of overflowing', (tester) async {
    await _pump(tester, [_dev('192.168.6.225')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    container
        .read(columnWidthsProvider.notifier)
        .resize(ResizableColumn.ip, -1000);
    await tester.pump();

    expect(container.read(columnWidthsProvider).ip, kMinColumnWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the toolbar shows the version and an About button',
      (tester) async {
    await _pump(tester, []);

    expect(find.byTooltip('About'), findsOneWidget);
    expect(find.textContaining('1.'), findsOneWidget);
  });

  testWidgets('the toolbar has a Settings button that opens SettingsScreen',
      (tester) async {
    await _pump(tester, []);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets); // AppBar title + tooltip text
  });
}
