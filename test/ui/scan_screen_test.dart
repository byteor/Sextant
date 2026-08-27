import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/device_identity.dart';
import 'package:sextant/data/history_database.dart';
import 'package:sextant/l10n/gen/app_localizations.dart';
import 'package:sextant/l10n/supported_locales.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/scan/ipv4_subnet.dart';
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

class _SpyScanController extends _FixedScanController {
  _SpyScanController(super.state);
  Device? startedDevice;
  ScanNetwork? startedNetwork;

  @override
  Future<List<int>?> startDeepPortScan(
    Device device,
    ScanNetwork network,
  ) async {
    startedDevice = device;
    startedNetwork = network;
    return null;
  }
}

class _SpyCancelScanController extends _FixedScanController {
  _SpyCancelScanController(super.state);
  bool cancelled = false;

  @override
  void cancelDeepPortScan() {
    cancelled = true;
  }
}

Device _dev(String ip, {String? mac}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, mac: mac, firstSeen: t, lastSeen: t);
}

ScanNetwork _network() {
  final addr = InternetAddress('192.168.1.10');
  return ScanNetwork(
    interfaceName: 'en0',
    displayName: 'Wi-Fi',
    address: addr,
    subnet: Ipv4Subnet.fromHostAndPrefix(addr, 24),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<Device> devices, {
  ScanState? state,
  List<ScanNetwork> networks = const [],
  HistoryDatabase? historyDatabase,
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
  addTearDown(
    () => tester.runAsync(() async {
      if (await tempDir!.exists()) await tempDir.delete(recursive: true);
    }),
  );

  final container = ProviderContainer(
    overrides: [
      scanControllerProvider.overrideWith(
        () => _FixedScanController(state ?? ScanState(devices: devices)),
      ),
      networksProvider.overrideWith((ref) async => networks),
      // settingsProvider also reads the app-support directory via
      // path_provider — overridden so opening the Settings screen
      // (pushed on top of this widget tree) resolves deterministically.
      settingsFileDirProvider.overrideWith((ref) async => tempDir!.path),
      if (historyDatabase != null)
        historyDatabaseProvider.overrideWithValue(historyDatabase),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(settingsProvider.future));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        home: const ScanScreen(),
      ),
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
    test(
      'is 0 when the host count is not yet known (avoids divide-by-zero)',
      () {
        expect(const ScanState(backgroundTotal: 0).backgroundProgress, 0);
      },
    );

    test('is scanned/total once the host count is known', () {
      expect(
        const ScanState(
          backgroundScanned: 3,
          backgroundTotal: 12,
        ).backgroundProgress,
        0.25,
      );
    });
  });

  testWidgets('the version/About/Settings group is flush to the right edge', (
    tester,
  ) async {
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

  testWidgets('a background monitor re-scan shows a determinate progress bar', (
    tester,
  ) async {
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
    expect(
      tester.widget<LinearProgressIndicator>(bar).value,
      closeTo(0.25, 1e-9),
    );
  });

  testWidgets('an idle (non-scanning) state shows no progress bar', (
    tester,
  ) async {
    await _pump(tester, []);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('there is no "Network map" button in the toolbar', (
    tester,
  ) async {
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

  testWidgets('the toolbar shows the version and an About button', (
    tester,
  ) async {
    await _pump(tester, []);

    expect(find.byTooltip('About'), findsOneWidget);
    expect(find.textContaining('1.'), findsOneWidget);
  });

  testWidgets('the toolbar has a Settings button that opens SettingsScreen', (
    tester,
  ) async {
    await _pump(tester, []);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets); // AppBar title + tooltip text
  });

  group('the "just discovered" row highlight', () {
    testWidgets('a device in justDiscoveredIdentities gets a green row '
        'background', (tester) async {
      final device = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa');
      final identity = deviceIdentity(mac: device.mac);
      await _pump(
        tester,
        [],
        state: ScanState(
          devices: [device],
          justDiscoveredIdentities: {identity},
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DeviceRow),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.green.withValues(alpha: 0.15));
    });

    testWidgets('a device not in justDiscoveredIdentities keeps its normal '
        'background', (tester) async {
      final device = _dev('10.0.0.6', mac: 'bb:bb:bb:bb:bb:bb');
      await _pump(tester, [], state: ScanState(devices: [device]));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DeviceRow),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.transparent);
    });
  });

  group('the "new devices" toolbar button', () {
    late HistoryDatabase historyDb;

    setUp(() => historyDb = HistoryDatabase(NativeDatabase.memory()));
    tearDown(() => historyDb.close());

    testWidgets('is hidden when no network is selected', (tester) async {
      await _pump(tester, []); // no networks -> no selected network

      expect(find.byTooltip('New devices'), findsNothing);
    });

    testWidgets('shows no badge when there are no unacknowledged new '
        'devices', (tester) async {
      final network = _network();
      await _pump(tester, [], networks: [network], historyDatabase: historyDb);
      await tester.pump(const Duration(milliseconds: 50));

      final button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('New devices'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.isSelected, isFalse);
    });

    testWidgets('shows the unread count, and opening the dialog '
        'acknowledges it', (tester) async {
      final network = _network();
      final networkId = network.id;
      // First scan establishes the baseline; the second reports 'bb' as new.
      await historyDb.recordNewDevices(networkId, [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
      ]);
      await historyDb.recordNewDevices(networkId, [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
      ]);
      expect(await historyDb.unacknowledgedCount(networkId), 1);

      await _pump(tester, [], networks: [network], historyDatabase: historyDb);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('New devices'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.isSelected, isTrue);

      await tester.tap(find.byTooltip('New devices'));
      await tester.pumpAndSettle();

      // The entry's title is its displayName, which for a hostname-less
      // device falls back to the IP — an exact match distinguishes it from
      // the subtitle's "10.0.0.2 · <date>" text, which also contains it.
      expect(find.text('10.0.0.2'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(await historyDb.unacknowledgedCount(networkId), 0);
    });
  });

  group('the "scan all ports" context menu item', () {
    testWidgets('appears when long-pressing a device row', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      await _pump(tester, [device]);

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();

      expect(find.text('Scan all ports (65,535)…'), findsOneWidget);
    });

    testWidgets('tapping it while a regular scan is running does not open '
        'the confirm dialog', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      await _pump(tester, [
        device,
      ], state: ScanState(devices: [device], isScanning: true));

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan all 65,535 ports on'), findsNothing);
    });

    testWidgets('confirming the dialog starts a deep scan on the right '
        'device and network', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      final network = _network();
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyScanController(ScanState(devices: [device])),
          ),
          networksProvider.overrideWith((ref) async => [network]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();

      expect(find.text('Scan all 65,535 ports on 10.0.0.7?'), findsOneWidget);

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      final spy =
          container.read(scanControllerProvider.notifier) as _SpyScanController;
      expect(spy.startedDevice?.ip, '10.0.0.7');
      expect(spy.startedNetwork, same(network));
    });

    testWidgets('cancelling the confirm dialog does not start a scan', (
      tester,
    ) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      final network = _network();
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyScanController(ScanState(devices: [device])),
          ),
          networksProvider.overrideWith((ref) async => [network]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final spy =
          container.read(scanControllerProvider.notifier) as _SpyScanController;
      expect(spy.startedDevice, isNull);
    });
  });

  group('deep scan progress display', () {
    testWidgets('the deep-scanned device\'s row shows a progress ring '
        'instead of its status dot', (tester) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      final identity = deviceIdentity(mac: device.mac);
      await _pump(
        tester,
        [],
        state: ScanState(
          devices: [device],
          isDeepScanning: true,
          deepScanDeviceIdentity: identity,
          deepScanIp: device.ip,
          deepScanCompleted: 100,
          deepScanTotal: 65535,
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DeviceRow),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the status bar shows deep-scan progress and a cancel '
        'button while running', (tester) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      await _pump(
        tester,
        [],
        state: ScanState(
          devices: [device],
          isDeepScanning: true,
          deepScanDeviceIdentity: deviceIdentity(mac: device.mac),
          deepScanIp: '10.0.0.8',
          deepScanCompleted: 100,
          deepScanTotal: 65535,
        ),
      );

      expect(find.text('Deep-scanning 10.0.0.8 — 100 / 65535'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('the status bar shows no deep-scan line when not deep '
        'scanning', (tester) async {
      await _pump(tester, []);

      expect(find.textContaining('Deep-scanning'), findsNothing);
    });

    testWidgets('tapping Cancel in the status bar calls cancelDeepPortScan', (
      tester,
    ) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyCancelScanController(
              ScanState(
                devices: [device],
                isDeepScanning: true,
                deepScanDeviceIdentity: deviceIdentity(mac: device.mac),
                deepScanIp: device.ip,
                deepScanCompleted: 10,
                deepScanTotal: 65535,
              ),
            ),
          ),
          networksProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));

      final spy =
          container.read(scanControllerProvider.notifier)
              as _SpyCancelScanController;
      expect(spy.cancelled, isTrue);
    });
  });
}
